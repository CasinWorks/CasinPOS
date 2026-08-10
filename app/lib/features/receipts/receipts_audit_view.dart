import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import 'receipt_pdf.dart';
import 'receipt_preview_page.dart';

class ReceiptsAuditView extends ConsumerWidget {
  const ReceiptsAuditView({super.key});

  ReceiptPdfContext _pdfContext(WidgetRef ref) {
    final membership = ref.read(activeMembershipProvider);
    String? cashier;
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      cashier = (user?.userMetadata?['full_name'] as String?) ?? user?.email;
    } catch (_) {}

    return ReceiptPdfContext(
      storeName: membership?.store.name ?? 'CasinPOS Store',
      currencySymbol: membership?.store.currencySymbol ?? '₱',
      cashierName: cashier,
      businessTypeLabel: membership?.store.businessType.value == 'restaurant'
          ? 'Restaurant'
          : 'Retail',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Include voided so audit shows clear paid vs voided distinction.
    final orders = ref.watch(ordersProvider);

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Receipts & Sales Audit',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Completed and voided transactions — preview & print paid receipts as PDF',
            style: TextStyle(fontSize: 12, color: AppColors.slate400),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No completed receipt transactions recorded yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
              ),
            )
          else
            for (final o in orders)
              _ReceiptRow(
                order: o,
                onPreview: o.isPaid
                    ? () => openReceiptPdfPreview(
                          context,
                          order: o,
                          pdfContext: _pdfContext(ref),
                        )
                    : null,
              ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.order, this.onPreview});

  final PosOrder order;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final voided = order.isVoided;
    final TextStyle mutedStrike = TextStyle(
      decoration: voided ? TextDecoration.lineThrough : null,
      decorationThickness: 2,
      color: voided ? AppColors.slate400 : AppColors.ink,
    );

    return Opacity(
      opacity: voided ? 0.65 : 1,
      child: Material(
        color: voided ? const Color(0xFFF1F5F9) : AppColors.scaffold,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPreview,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: voided ? AppColors.slate300 : const Color(0xFFA7F3D0),
                width: voided ? 1 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: voided ? AppColors.slate400 : AppColors.slate900,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    voided ? Icons.block : Icons.receipt_long,
                    color: voided ? Colors.white : AppColors.retail,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              order.orderNo,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                decoration: voided ? TextDecoration.lineThrough : null,
                                color: voided ? AppColors.slate400 : AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: voided ? AppColors.slate200 : AppColors.slate200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              order.paymentMethod.label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                decoration: voided ? TextDecoration.lineThrough : null,
                                color: voided ? AppColors.slate500 : AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        voided
                            ? 'Voided transaction • ${order.timestampLabel}'
                            : 'Walk-in Customer • ${order.timestampLabel} • ${order.items.length} item(s)',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.slate400,
                          decoration: voided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ).merge(mutedStrike),
                    ),
                    Row(
                      children: [
                        Icon(
                          voided ? Icons.cancel_outlined : Icons.check_circle,
                          size: 12,
                          color: voided ? AppColors.slate500 : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          voided ? 'Voided' : 'Paid',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: voided ? AppColors.slate500 : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (onPreview != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Preview PDF',
                    onPressed: onPreview,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.slate200),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
