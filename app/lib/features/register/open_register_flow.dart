import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/input/numeric_formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/permissions.dart';
import '../auth/confirm_password.dart';

/// Returns `true` when an open cash session exists (already open or newly opened).
///
/// Used before checkout. Staff cannot open — they are told a manager must unlock.
/// Managers+ confirm, re-enter their signed-in password, then enter opening float.
Future<bool> ensureCashRegisterOpenForCheckout(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    await ref.read(cashRegisterProvider.notifier).refresh();
  } catch (_) {}

  final balance = ref.read(cashRegisterProvider).valueOrNull;
  if (balance != null) return true;

  if (!context.mounted) return false;

  final membership = ref.read(activeMembershipProvider);
  final role = membership?.role;
  final canOpen = role != null && Permissions.canOpenCashRegister(role);

  final action = await showDialog<_RegisterClosedAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Cash register is closed'),
      content: Text(
        canOpen
            ? 'Sales cannot complete while the register is closed. '
                'Open the register with an opening float to continue checkout.'
            : 'Sales cannot complete while the register is closed. '
                'Ask an owner, admin, or manager to open the cash register, then try again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _RegisterClosedAction.cancel),
          style: TextButton.styleFrom(minimumSize: const Size(88, 52)),
          child: const Text('Cancel'),
        ),
        if (canOpen)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _RegisterClosedAction.open),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.slate900,
              minimumSize: const Size(140, 52),
            ),
            child: const Text('Open register'),
          ),
      ],
    ),
  );

  if (action != _RegisterClosedAction.open || !context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Open cash register?'),
      content: const Text('Are you sure you want to open the cash register?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(minimumSize: const Size(88, 52)),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.slate900,
            minimumSize: const Size(120, 52),
          ),
          child: const Text('Yes, open'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final email = ref.read(authRepositoryProvider).currentUser?.email?.trim() ?? '';
  final authOk = await confirmSignedInPassword(
    context,
    ref,
    title: 'Manager password',
    body: 'Re-enter your password for $email to open the register.',
  );
  if (!authOk || !context.mounted) return false;

  final symbol = membership?.store.currencySymbol ?? '₱';
  final float = await _askOpeningFloat(context, symbol: symbol);
  if (float == null || !context.mounted) return false;

  // Float dialog is closed — safe to refresh cashRegister without dialog listeners.
  try {
    await ref.read(cashRegisterProvider.notifier).open(openingFloat: float);
    if (!context.mounted) return false;
    showAppMessage(context, 'Register opened — you can complete the sale');
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    showAppError(context, e, fallback: 'Could not open the register');
    return false;
  }
}

enum _RegisterClosedAction { cancel, open }

Future<double?> _askOpeningFloat(
  BuildContext context, {
  required String symbol,
}) async {
  final ctrl = TextEditingController(text: '1000');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Opening float'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: NumericInput.moneyKeyboard,
        inputFormatters: NumericInput.money(),
        decoration: InputDecoration(
          labelText: 'Opening float ($symbol)',
          helperText: 'Cash counted in the drawer at start of shift',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(minimumSize: const Size(88, 52)),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.slate900,
            minimumSize: const Size(100, 52),
          ),
          child: const Text('Open'),
        ),
      ],
    ),
  );
  final amount = NumericInput.tryParseMoney(ctrl.text);
  ctrl.dispose();
  if (ok != true) return null;
  if (amount == null || amount < 0) {
    if (context.mounted) {
      showAppMessage(context, 'Enter a valid opening float amount', isError: true);
    }
    return null;
  }
  return amount;
}
