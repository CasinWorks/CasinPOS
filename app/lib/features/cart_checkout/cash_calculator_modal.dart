import 'package:flutter/material.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/input/numeric_formatters.dart';
import '../../../core/theme/app_colors.dart';

class CashCalcResult {
  const CashCalcResult({required this.received, required this.change});
  final double received;
  final double change;
}

Future<CashCalcResult?> showCashCalculatorModal(
  BuildContext context, {
  required double totalPayable,
  required double drawerBalance,
}) {
  return showDialog<CashCalcResult>(
    context: context,
    builder: (ctx) => _CashCalculatorDialog(
      totalPayable: totalPayable,
      drawerBalance: drawerBalance,
    ),
  );
}

class _CashCalculatorDialog extends StatefulWidget {
  const _CashCalculatorDialog({
    required this.totalPayable,
    required this.drawerBalance,
  });
  final double totalPayable;
  final double drawerBalance;

  @override
  State<_CashCalculatorDialog> createState() => _CashCalculatorDialogState();
}

class _CashCalculatorDialogState extends State<_CashCalculatorDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Leave room for dialog title, actions, and default inset padding when keyboard is up.
    final maxContentHeight = (media.size.height
            - media.viewInsets.bottom
            - media.padding.vertical
            - 200)
        .clamp(120.0, 520.0);

    final received = double.tryParse(_ctrl.text) ?? 0;
    final change = received - widget.totalPayable;
    final enoughPayment = received >= widget.totalPayable;
    final canMakeChange = !enoughPayment || change <= widget.drawerBalance + 0.001;
    final enough = enoughPayment && canMakeChange;
    final drawerAfter = widget.drawerBalance + widget.totalPayable;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      title: const Text('Cash calculator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: maxContentHeight,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.retail.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AMOUNT DUE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱${widget.totalPayable.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.8,
                        color: AppColors.retail,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer owes this amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cash in drawer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                    Text(
                      '₱${widget.drawerBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'After this sale: ₱${drawerAfter.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                keyboardType: NumericInput.moneyKeyboard,
                inputFormatters: NumericInput.money(),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Cash received',
                  prefixText: '₱ ',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in [100.0, 200.0, 500.0, 1000.0])
                    ActionChip(
                      label: Text(
                        '₱${q.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      onPressed: () => setState(() => _ctrl.text = q.toStringAsFixed(0)),
                    ),
                  ActionChip(
                    label: const Text('Exact', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    onPressed: () => setState(
                      () => _ctrl.text = widget.totalPayable.toStringAsFixed(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: !enoughPayment
                      ? AppColors.slate100
                      : !canMakeChange
                          ? const Color(0xFFFFF1F2)
                          : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !enoughPayment
                        ? AppColors.slate200
                        : !canMakeChange
                            ? const Color(0xFFFECDD3)
                            : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !enoughPayment
                          ? 'Need ₱${(widget.totalPayable - received).toStringAsFixed(2)} more'
                          : !canMakeChange
                              ? 'Not enough cash in drawer for change'
                              : 'Change due: ₱${change.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: !enoughPayment
                            ? AppColors.slate600
                            : !canMakeChange
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF065F46),
                      ),
                    ),
                    if (enoughPayment && !canMakeChange) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Drawer has ₱${widget.drawerBalance.toStringAsFixed(2)} but change is '
                        '₱${change.toStringAsFixed(2)}. Add a pay-in or ask for exact change.',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9F1239),
                        ),
                      ),
                    ],
                    if (enough) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Drawer: +₱${received.toStringAsFixed(2)} in · '
                        '−₱${change.toStringAsFixed(2)} change · '
                        'net +₱${widget.totalPayable.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size(88, 52)),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: enough
              ? () {
                  final parsed = NumericInput.tryParseMoney(_ctrl.text);
                  if (parsed == null) {
                    showAppMessage(context, 'Enter a valid cash amount', isError: true);
                    return;
                  }
                  final ch = parsed - widget.totalPayable;
                  if (ch > widget.drawerBalance + 0.001) {
                    showAppMessage(
                      context,
                      'Not enough cash in drawer to give change',
                      isError: true,
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    CashCalcResult(received: parsed, change: ch),
                  );
                }
              : null,
          style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
          child: const Text('Confirm payment'),
        ),
      ],
    );
  }
}
