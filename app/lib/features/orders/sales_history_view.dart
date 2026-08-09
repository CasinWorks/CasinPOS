import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/permissions.dart';

class SalesHistoryView extends ConsumerWidget {
  const SalesHistoryView({super.key});

  Future<void> _voidSale(BuildContext context, WidgetRef ref, PosOrder order) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Void this sale?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Void ${order.orderNo} (₱${order.total.toStringAsFixed(2)}). '
              'Stock returns to inventory and this sale is excluded from reports.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Wrong items, customer cancelled',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            child: const Text('Void sale'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(ordersProvider.notifier).voidSale(
            order: order,
            reason: reason.isEmpty ? null : reason,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order.orderNo} voided — stock restored'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not void: $e'),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final role = ref.watch(activeMembershipProvider)?.role;
    final canVoid = role != null && Permissions.canVoidSales(role);

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Sales History',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Paid sales and voids — managers can void a sale to restock inventory',
            style: TextStyle(fontSize: 12, color: AppColors.slate400),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No sales yet in this store.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final o in orders)
                  SizedBox(
                    width: 360,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: o.isVoided ? const Color(0xFFFFF1F2) : AppColors.scaffold,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: o.isVoided ? const Color(0xFFFECDD3) : AppColors.slate200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o.orderNo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        decoration:
                                            o.isVoided ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    Text(
                                      'Retail · ${o.paymentMethod.label} · ${o.timestampLabel}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: o.isVoided
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      o.isVoided ? Icons.block : Icons.check,
                                      size: 12,
                                      color: o.isVoided
                                          ? const Color(0xFFB91C1C)
                                          : const Color(0xFF047857),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      o.status,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: o.isVoided
                                            ? const Color(0xFF991B1B)
                                            : const Color(0xFF065F46),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.slate100),
                            ),
                            child: Column(
                              children: [
                                for (final item in o.items)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item.qty}x ${item.name}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '₱${(item.unitPrice * item.qty).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Total: ₱${o.total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                              ),
                              if (canVoid && o.isPaid)
                                TextButton.icon(
                                  onPressed: () => _voidSale(context, ref, o),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(88, 48),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.undo_rounded, size: 22, color: Color(0xFFE11D48)),
                                  label: const Text(
                                    'Void',
                                    style: TextStyle(
                                      color: Color(0xFFE11D48),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
