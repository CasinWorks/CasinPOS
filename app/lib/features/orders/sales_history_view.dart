import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/permissions.dart';
import 'refund_sale_dialog.dart';

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

  Future<void> _refundSale(BuildContext context, WidgetRef ref, PosOrder order) async {
    final selection = await showRefundSaleDialog(context, order: order);
    if (selection == null || !context.mounted) return;
    try {
      await ref.read(ordersProvider.notifier).refundSale(
            order: order,
            lines: selection.lines,
            reason: selection.reason,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order.orderNo} refunded — stock restored'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not refund: $e'),
          backgroundColor: const Color(0xFFEA580C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final role = ref.watch(activeMembershipProvider)?.role;
    final canManageReturns = role != null && Permissions.canVoidSales(role);

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
            'Paid, refunded, and voided sales — managers can refund or void',
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
                    child: _SaleHistoryCard(
                      order: o,
                      canVoid: canManageReturns && o.isPaid && !o.isPartiallyRefunded && !o.isRefunded,
                      canRefund: canManageReturns && o.canRefund,
                      onVoid: () => _voidSale(context, ref, o),
                      onRefund: () => _refundSale(context, ref, o),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SaleHistoryCard extends StatelessWidget {
  const _SaleHistoryCard({
    required this.order,
    required this.canVoid,
    required this.canRefund,
    required this.onVoid,
    required this.onRefund,
  });

  final PosOrder order;
  final bool canVoid;
  final bool canRefund;
  final VoidCallback onVoid;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final voided = order.isVoided;
    final refunded = order.isRefunded;
    final partial = order.isPartiallyRefunded;
    final muted = voided || refunded;

    final badgeColor = voided
        ? AppColors.slate200
        : refunded
            ? const Color(0xFFFFEDD5)
            : partial
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFD1FAE5);
    final badgeFg = voided
        ? AppColors.slate600
        : refunded
            ? const Color(0xFF9A3412)
            : partial
                ? const Color(0xFF92400E)
                : const Color(0xFF065F46);
    final badgeIcon = voided
        ? Icons.block
        : refunded
            ? Icons.keyboard_return_rounded
            : partial
                ? Icons.replay_circle_filled_outlined
                : Icons.check;
    final badgeLabel = voided
        ? 'Voided'
        : refunded
            ? 'Refunded'
            : partial
                ? 'Partial refund'
                : 'Paid';

    return Opacity(
      opacity: muted ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: muted ? const Color(0xFFF8FAFC) : AppColors.scaffold,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: muted
                ? AppColors.slate300
                : partial
                    ? const Color(0xFFFCD34D)
                    : const Color(0xFFA7F3D0),
            width: muted ? 1 : 1.5,
          ),
        ),
        child: Stack(
          children: [
            if (voided || refunded)
              Positioned(
                top: 0,
                right: 0,
                child: Transform.rotate(
                  angle: 0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: voided ? AppColors.slate200 : const Color(0xFFFED7AA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      voided ? 'VOIDED' : 'REFUNDED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: voided ? AppColors.slate500 : const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              decoration: muted ? TextDecoration.lineThrough : null,
                              decorationThickness: 2,
                              color: muted ? AppColors.slate400 : AppColors.ink,
                            ),
                          ),
                          Text(
                            'Retail · ${order.paymentMethod.label} · ${order.timestampLabel}',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.slate400,
                              decoration: muted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeFg),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeFg,
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
                    color: muted ? const Color(0xFFF1F5F9) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate100),
                  ),
                  child: Column(
                    children: [
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.refundedQty > 0
                                      ? '${item.qty}x ${item.name} (↺${item.refundedQty})'
                                      : '${item.qty}x ${item.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    decoration: muted ? TextDecoration.lineThrough : null,
                                    color: muted ? AppColors.slate400 : AppColors.ink,
                                  ),
                                ),
                              ),
                              Text(
                                '₱${(item.unitPrice * item.qty).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  decoration: muted ? TextDecoration.lineThrough : null,
                                  color: muted ? AppColors.slate400 : AppColors.ink,
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
                        order.refundedTotal > 0
                            ? 'Net: ₱${order.netTotal.toStringAsFixed(2)}'
                            : 'Total: ₱${order.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          decoration: muted ? TextDecoration.lineThrough : null,
                          decorationThickness: 2,
                          color: muted ? AppColors.slate400 : AppColors.ink,
                        ),
                      ),
                    ),
                    if (canRefund)
                      TextButton.icon(
                        onPressed: onRefund,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(88, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        icon: const Icon(Icons.keyboard_return_rounded, size: 20, color: Color(0xFFEA580C)),
                        label: const Text(
                          'Refund',
                          style: TextStyle(
                            color: Color(0xFFEA580C),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (canVoid)
                      TextButton.icon(
                        onPressed: onVoid,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(72, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        icon: const Icon(Icons.block, size: 20, color: Color(0xFFE11D48)),
                        label: const Text(
                          'Void',
                          style: TextStyle(
                            color: Color(0xFFE11D48),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
