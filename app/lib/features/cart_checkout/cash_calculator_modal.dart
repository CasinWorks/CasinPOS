import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/input/numeric_formatters.dart';
import '../../../core/theme/app_colors.dart';

class CashCalcResult {
  const CashCalcResult({required this.received, required this.change});
  final double received;
  final double change;
}

/// Common Philippine cash denominations (notes + coins).
const _billDenoms = <double>[50, 100, 200, 500, 1000];
const _coinDenoms = <double>[1, 5, 10, 20];

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
  final _counts = <double, int>{
    for (final d in [..._billDenoms, ..._coinDenoms]) d: 0,
  };
  final _manualCtrl = TextEditingController();
  var _useManual = false;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  double get _countedTotal {
    var sum = 0.0;
    for (final e in _counts.entries) {
      sum += e.key * e.value;
    }
    return sum;
  }

  double get _received {
    if (_useManual) {
      return NumericInput.tryParseMoney(_manualCtrl.text) ?? 0;
    }
    return _countedTotal;
  }

  void _bump(double denom, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _useManual = false;
      _manualCtrl.clear();
      final next = (_counts[denom] ?? 0) + delta;
      _counts[denom] = next < 0 ? 0 : next;
    });
  }

  void _clearCounts() {
    setState(() {
      for (final d in _counts.keys.toList()) {
        _counts[d] = 0;
      }
      _manualCtrl.clear();
      _useManual = false;
    });
  }

  void _setExact() {
    setState(() {
      _useManual = false;
      _manualCtrl.clear();
      for (final d in _counts.keys.toList()) {
        _counts[d] = 0;
      }
      // Prefer fewest high bills, then fill remainder with coins.
      var left = (widget.totalPayable * 100).round(); // centavos
      for (final d in [..._billDenoms.reversed, ..._coinDenoms.reversed]) {
        final unit = (d * 100).round();
        if (unit <= 0) continue;
        final n = left ~/ unit;
        _counts[d] = n;
        left -= n * unit;
      }
      // Leftover centavos (< ₱1): bump into manual if any.
      if (left > 0) {
        _useManual = true;
        _manualCtrl.text = widget.totalPayable.toStringAsFixed(2);
        for (final d in _counts.keys.toList()) {
          _counts[d] = 0;
        }
      }
    });
  }

  Widget _denomRow(double denom) {
    final count = _counts[denom] ?? 0;
    final label = denom >= 1 && denom == denom.roundToDouble()
        ? '₱${denom.toStringAsFixed(0)}'
        : '₱${denom.toStringAsFixed(2)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.accentSoft : AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0 ? AppColors.retail.withValues(alpha: 0.45) : AppColors.slate200,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: count > 0 ? () => _bump(denom, -1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: count > 0 ? AppColors.ink : AppColors.slate400,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _bump(denom, 1),
            icon: const Icon(Icons.add_circle, size: 26, color: AppColors.retailDark),
          ),
          const Spacer(),
          Text(
            count > 0 ? '₱${(denom * count).toStringAsFixed(0)}' : '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxContentHeight = (media.size.height
            - media.viewInsets.bottom
            - media.padding.vertical
            - 180)
        .clamp(160.0, 640.0);

    final received = _received;
    final change = received - widget.totalPayable;
    final enoughPayment = received >= widget.totalPayable - 0.001;
    final canMakeChange = !enoughPayment || change <= widget.drawerBalance + 0.001;
    final enough = enoughPayment && canMakeChange;
    final drawerAfter = widget.drawerBalance + widget.totalPayable;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: const Text('Cash calculator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
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
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.8,
                        color: AppColors.retail,
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
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cash received',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                  Text(
                    '₱${received.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap + for each bill or coin the customer gave you. No typing needed.',
                style: TextStyle(fontSize: 11, color: AppColors.slate500, height: 1.35),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Exact', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: _setExact,
                  ),
                  ActionChip(
                    label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: _clearCounts,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Bills', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              for (final d in _billDenoms) ...[
                _denomRow(d),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 4),
              const Text('Coins', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              for (final d in _coinDenoms) ...[
                _denomRow(d),
                const SizedBox(height: 6),
              ],
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: false,
                  onExpansionChanged: (open) {
                    if (!open) {
                      setState(() {
                        _useManual = false;
                        _manualCtrl.clear();
                      });
                      FocusScope.of(context).unfocus();
                    }
                  },
                  title: const Text(
                    'Type amount instead',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Opens keyboard — use only if needed',
                    style: TextStyle(fontSize: 11, color: AppColors.slate500),
                  ),
                  children: [
                    TextField(
                      controller: _manualCtrl,
                      autofocus: false,
                      keyboardType: NumericInput.moneyKeyboard,
                      inputFormatters: NumericInput.money(),
                      onChanged: (_) => setState(() {
                        _useManual = true;
                        for (final d in _counts.keys.toList()) {
                          _counts[d] = 0;
                        }
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Cash received',
                        prefixText: '₱ ',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                          ? (received <= 0
                              ? 'Count the cash received above'
                              : 'Need ₱${(widget.totalPayable - received).toStringAsFixed(2)} more')
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
                  final parsed = received;
                  if (parsed <= 0) {
                    showAppMessage(context, 'Count cash received first', isError: true);
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
