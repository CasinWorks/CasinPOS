import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

class CashCalcResult {
  const CashCalcResult({required this.received, required this.change});
  final double received;
  final double change;
}

Future<CashCalcResult?> showCashCalculatorModal(
  BuildContext context, {
  required double totalPayable,
}) {
  return showDialog<CashCalcResult>(
    context: context,
    builder: (ctx) => _CashCalculatorDialog(totalPayable: totalPayable),
  );
}

class _CashCalculatorDialog extends StatefulWidget {
  const _CashCalculatorDialog({required this.totalPayable});
  final double totalPayable;

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
        .clamp(120.0, 420.0);

    final received = double.tryParse(_ctrl.text) ?? 0;
    final change = received - widget.totalPayable;
    final enough = received >= widget.totalPayable;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      title: const Text('Cash calculator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 320,
          maxHeight: maxContentHeight,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Total payable: ₱${widget.totalPayable.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
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
                  color: enough ? const Color(0xFFECFDF5) : AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  enough
                      ? 'Change: ₱${change.toStringAsFixed(2)}'
                      : 'Need ₱${(widget.totalPayable - received).toStringAsFixed(2)} more',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: enough ? const Color(0xFF065F46) : AppColors.slate600,
                  ),
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
              ? () => Navigator.pop(
                    context,
                    CashCalcResult(received: received, change: change),
                  )
              : null,
          style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
          child: const Text('Confirm payment'),
        ),
      ],
    );
  }
}
