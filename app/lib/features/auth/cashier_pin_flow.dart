import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/team_models.dart';
import '../../data/providers/pos_providers.dart';
import '../../data/providers/session_providers.dart';
import 'confirm_password.dart';
import 'pin_pad.dart';

/// Prefer signed-in user's cashier PIN; fall back to account password.
Future<bool> confirmManagerStepUp(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String body,
}) async {
  final membership = ref.read(activeMembershipProvider);
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (membership == null || userId == null) return false;

  var hasPin = false;
  try {
    hasPin = await ref.read(storeRepositoryProvider).myStoreHasPin(membership.storeId);
  } catch (_) {}

  if (!hasPin) {
    if (!context.mounted) return false;
    return confirmSignedInPassword(
      context,
      ref,
      title: title,
      body: body,
    );
  }

  while (context.mounted) {
    final pin = await showPinPadDialog(
      context,
      title: title,
      subtitle: '$body\nEnter your 4–6 digit cashier PIN.',
      confirmLabel: 'Verify PIN',
    );
    if (pin == null) return false;
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return false;
    try {
      await ref.read(storeRepositoryProvider).verifyMemberPin(
            storeId: membership.storeId,
            userId: userId,
            pin: pin,
          );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      showAppError(context, e);
    }
  }
  return false;
}

/// Switch / claim cashier on the open drawer via PIN.
Future<void> showSwitchCashierDialog(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
}) async {
  final storeId = ref.read(activeMembershipProvider)?.storeId;
  if (storeId == null) return;

  List<ShiftRosterMember> roster;
  try {
    roster = await ref.read(storeRepositoryProvider).listShiftRoster(storeId);
  } catch (e) {
    if (context.mounted) showAppError(context, e);
    return;
  }
  if (!context.mounted) return;

  final withPin = roster.where((m) => m.hasPin).toList();
  if (withPin.isEmpty) {
    showAppMessage(
      context,
      'No teammate has a cashier PIN yet. Set one under Invite / Manage → Team.',
      isError: true,
    );
    return;
  }

  final selected = await showDialog<ShiftRosterMember>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Switch cashier'),
      content: SizedBox(
        width: 360,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: withPin.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final m = withPin[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.slate200,
                child: Text(
                  m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              title: Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(m.role.value),
              onTap: () => Navigator.pop(ctx, m),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ),
  );
  if (selected == null || !context.mounted) return;

  final pin = await showPinPadDialog(
    context,
    title: 'Cashier PIN',
    subtitle: 'Enter PIN for ${selected.displayName}',
    confirmLabel: 'Claim shift',
  );
  if (pin == null || !context.mounted) return;

  try {
    await ref.read(cashRegisterProvider.notifier).claimWithPin(
          sessionId: sessionId,
          userId: selected.userId,
          pin: pin,
        );
    if (!context.mounted) return;
    showAppMessage(context, 'Shift claimed by ${selected.displayName}');
  } catch (e) {
    if (!context.mounted) return;
    showAppError(context, e);
  }
}
