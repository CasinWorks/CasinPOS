import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';

/// Returns `true` when the cashier confirms the order review.
Future<bool> showOrderReviewModal(
  BuildContext context, {
  required List<CartLine> lines,
  required CartTotals totals,
  required PaymentMethod paymentMethod,
  String currencySymbol = '₱',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OrderReviewDialog(
      lines: lines,
      totals: totals,
      paymentMethod: paymentMethod,
      currencySymbol: currencySymbol,
    ),
  );
  return result == true;
}

class _OrderReviewDialog extends StatelessWidget {
  const _OrderReviewDialog({
    required this.lines,
    required this.totals,
    required this.paymentMethod,
    required this.currencySymbol,
  });

  final List<CartLine> lines;
  final CartTotals totals;
  final PaymentMethod paymentMethod;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final itemCount = lines.fold<int>(0, (s, l) => s + l.quantity);
    final media = MediaQuery.of(context);
    final maxH = (media.size.height * 0.72).clamp(280.0, 560.0);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review order',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          SizedBox(height: 4),
          Text(
            'Verify items and total before charging the customer',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$itemCount item${itemCount == 1 ? '' : 's'} · ${paymentMethod.label}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.scaffold,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final line = lines[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.slate900,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${line.quantity}',
                            style: const TextStyle(
                              color: AppColors.retail,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.product.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '$currencySymbol${line.product.price.toStringAsFixed(2)} each',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.slate500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$currencySymbol${line.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text(
                    'Total to charge',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$currencySymbol${totals.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.retail,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(minimumSize: const Size(88, 52)),
          child: const Text('Back to cart'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.slate900,
            foregroundColor: Colors.white,
            minimumSize: const Size(180, 52),
          ),
          child: Text(
            paymentMethod == PaymentMethod.cash
                ? 'Confirm · Cash calc'
                : 'Confirm · Charge',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
