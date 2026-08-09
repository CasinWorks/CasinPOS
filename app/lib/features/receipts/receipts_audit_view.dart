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
    final orders = ref.watch(paidOrdersProvider);

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
            'Completed transactions & payment history — preview & print as PDF',
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
              Material(
                color: AppColors.scaffold,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => openReceiptPdfPreview(
                    context,
                    order: o,
                    pdfContext: _pdfContext(ref),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.slate900,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.receipt_long, color: AppColors.retail, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(o.orderNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate200,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      o.paymentMethod.label,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Walk-in Customer • ${o.timestampLabel} • ${o.items.length} item(s)',
                                style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${o.total.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                            const Row(
                              children: [
                                Icon(Icons.check_circle, size: 12, color: AppColors.success),
                                SizedBox(width: 4),
                                Text(
                                  'Paid',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Preview PDF',
                          onPressed: () => openReceiptPdfPreview(
                            context,
                            order: o,
                            pdfContext: _pdfContext(ref),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.slate200),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
