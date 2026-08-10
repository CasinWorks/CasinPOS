import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';

class RefundSelection {
  const RefundSelection({
    required this.lines,
    this.reason,
  });

  final List<({String? itemId, String name, int qty})> lines;
  final String? reason;
}

Future<RefundSelection?> showRefundSaleDialog(
  BuildContext context, {
  required PosOrder order,
}) {
  return showDialog<RefundSelection>(
    context: context,
    builder: (ctx) => _RefundSaleDialog(order: order),
  );
}

class _RefundSaleDialog extends StatefulWidget {
  const _RefundSaleDialog({required this.order});
  final PosOrder order;

  @override
  State<_RefundSaleDialog> createState() => _RefundSaleDialogState();
}

class _RefundSaleDialogState extends State<_RefundSaleDialog> {
  late final Map<int, int> _qty;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qty = {
      for (var i = 0; i < widget.order.items.length; i++)
        i: widget.order.items[i].refundableQty > 0 ? widget.order.items[i].refundableQty : 0,
    };
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  double get _refundTotal {
    var t = 0.0;
    for (var i = 0; i < widget.order.items.length; i++) {
      final q = _qty[i] ?? 0;
      t += widget.order.items[i].unitPrice * q;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Refund sale'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.order.orderNo} · pick items / qty to return',
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < widget.order.items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _RefundLineEditor(
                  line: widget.order.items[i],
                  qty: _qty[i] ?? 0,
                  onChanged: (v) => setState(() => _qty[i] = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. Damaged, customer change of mind',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Refund total',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      '₱${_refundTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.retail,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _refundTotal <= 0
              ? null
              : () {
                  final lines = <({String? itemId, String name, int qty})>[];
                  for (var i = 0; i < widget.order.items.length; i++) {
                    final q = _qty[i] ?? 0;
                    if (q <= 0) continue;
                    final item = widget.order.items[i];
                    lines.add((itemId: item.itemId, name: item.name, qty: q));
                  }
                  Navigator.pop(
                    context,
                    RefundSelection(
                      lines: lines,
                      reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
                    ),
                  );
                },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
          child: const Text('Confirm refund'),
        ),
      ],
    );
  }
}

class _RefundLineEditor extends StatelessWidget {
  const _RefundLineEditor({
    required this.line,
    required this.qty,
    required this.onChanged,
  });

  final OrderLine line;
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = line.refundableQty;
    final disabled = max <= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: disabled ? AppColors.slate100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    decoration: disabled ? TextDecoration.lineThrough : null,
                    color: disabled ? AppColors.slate400 : AppColors.ink,
                  ),
                ),
                Text(
                  disabled
                      ? 'Fully refunded'
                      : '₱${line.unitPrice.toStringAsFixed(2)} · $max refundable',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: disabled || qty <= 0 ? null : () => onChanged(qty - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$qty',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          IconButton(
            onPressed: disabled || qty >= max ? null : () => onChanged(qty + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          TextButton(
            onPressed: disabled
                ? null
                : () => onChanged(qty == max ? 0 : max),
            child: Text(qty == max ? 'Clear' : 'All'),
          ),
        ],
      ),
    );
  }
}
