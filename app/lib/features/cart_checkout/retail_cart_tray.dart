import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../onboarding/tutorial_anchors.dart';
import '../receipts/receipt_pdf.dart';
import '../receipts/receipt_preview_page.dart';
import '../register/open_register_flow.dart';
import 'cash_calculator_modal.dart';

class RetailCartTray extends ConsumerStatefulWidget {
  const RetailCartTray({super.key});

  @override
  ConsumerState<RetailCartTray> createState() => _RetailCartTrayState();
}

class _RetailCartTrayState extends ConsumerState<RetailCartTray> {
  final _promoCtrl = TextEditingController();

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    final settings = ref.read(checkoutSettingsProvider);
    final totals = ref.read(cartTotalsProvider);

    try {
      ref.read(cartProvider.notifier).assertWithinStock();
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e);
      return;
    }

    final registerOpen = await ensureCashRegisterOpenForCheckout(context, ref);
    if (!registerOpen || !mounted) return;

    if (settings.paymentMethod == PaymentMethod.cash) {
      final result = await showCashCalculatorModal(
        context,
        totalPayable: totals.total,
      );
      if (result == null || !mounted) return;
      await _completeSale(settings.paymentMethod, result.received, result.change);
    } else {
      await _completeSale(settings.paymentMethod, totals.total, 0);
    }
  }

  Future<void> _completeSale(PaymentMethod method, double received, double change) async {
    final cart = List<CartLine>.from(ref.read(cartProvider));
    final totals = ref.read(cartTotalsProvider);
    final membership = ref.read(activeMembershipProvider);
    String? cashier;
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      cashier = (user?.userMetadata?['full_name'] as String?) ?? user?.email;
    } catch (_) {}

    try {
      ref.read(cartProvider.notifier).assertWithinStock();

      final result = await ref.read(ordersProvider.notifier).completeSale(
            lines: cart,
            subtotal: totals.subtotal,
            tax: totals.tax,
            total: totals.total,
            paymentMethod: method,
            cashReceived: received,
            changeGiven: change,
          );
      await ref.read(posCatalogProvider.notifier).deductForSale(cart);
      ref.read(cartProvider.notifier).clear();
      if (method == PaymentMethod.cash) {
        unawaited(ref.read(cashRegisterProvider.notifier).refresh());
      }

      final order = result.order;
      final pdfContext = ReceiptPdfContext(
        storeName: membership?.store.name ?? 'CasinPOS Store',
        currencySymbol: membership?.store.currencySymbol ?? '₱',
        cashierName: cashier,
        businessTypeLabel: 'Retail',
      );

      if (!mounted) return;
      if (result.warning != null) {
        showAppMessage(context, result.warning!, isError: true);
      }

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 48),
              const SizedBox(height: 12),
              const Text('Purchase Complete!', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(
                'Paid via ${method.label}',
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
              if (method == PaymentMethod.cash && change > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Return Change: ₱${change.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                openReceiptPdfPreview(
                  context,
                  order: order,
                  pdfContext: pdfContext,
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Preview PDF'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e, fallback: 'Checkout failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final settings = ref.watch(checkoutSettingsProvider);
    final totals = ref.watch(cartTotalsProvider);
    final store = ref.watch(activeMembershipProvider)?.store;
    final enabledMethods = store?.enabledPaymentMethods ?? PaymentMethod.values;

    ref.listen(activeMembershipProvider, (prev, next) {
      final enabled = next?.store.enabledPaymentMethods ?? PaymentMethod.values;
      final current = ref.read(checkoutSettingsProvider).paymentMethod;
      if (!enabled.contains(current)) {
        ref.read(checkoutSettingsProvider.notifier).setPayment(PaymentMethod.cash);
      }
    });

    final itemCount = cart.fold<int>(0, (s, l) => s + l.quantity);

    return ColoredBox(
      color: AppColors.scaffold,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.slate200)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.restaurant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Retail Cart',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '$itemCount item(s) selected',
                            style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                          ),
                        ],
                      ),
                    ),
                    if (cart.isNotEmpty)
                      TextButton(
                        onPressed: () => ref.read(cartProvider.notifier).clear(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          minimumSize: const Size(64, 48),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const Divider(height: 20),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const Text(
                        'PAYMENT METHOD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.slate400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.1,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final m in enabledMethods)
                            _PayChip(
                              label: m.label,
                              selected: settings.paymentMethod == m,
                              onTap: () => ref.read(checkoutSettingsProvider.notifier).setPayment(m),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (cart.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 40, color: AppColors.slate300),
                              SizedBox(height: 8),
                              Text(
                                'Cart is currently empty',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate400,
                                ),
                              ),
                              Text(
                                'Tap products from POS to add to cart',
                                style: TextStyle(fontSize: 10, color: AppColors.slate400),
                              ),
                            ],
                          ),
                        )
                      else
                        for (var i = 0; i < cart.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _CartLineTile(index: i, line: cart[i]),
                        ],
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _VatChip(
                              label: 'Inclusive',
                              selected: settings.vatMode == VatMode.inclusive,
                              selectedColor: AppColors.success,
                              onTap: () =>
                                  ref.read(checkoutSettingsProvider.notifier).setVat(VatMode.inclusive),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _VatChip(
                              label: '+10% VAT',
                              selected: settings.vatMode == VatMode.plusTen,
                              selectedColor: const Color(0xFF2563EB),
                              onTap: () =>
                                  ref.read(checkoutSettingsProvider.notifier).setVat(VatMode.plusTen),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promoCtrl,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'Discount Code / Promo',
                                hintStyle: const TextStyle(fontSize: 11),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.slate200),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          FilledButton(
                            onPressed: () {
                              final code = _promoCtrl.text.trim().toUpperCase();
                              if (code == 'SENIOR20') {
                                ref.read(checkoutSettingsProvider.notifier).setDiscount(20);
                              } else if (code == 'PROMO10') {
                                ref.read(checkoutSettingsProvider.notifier).setDiscount(10);
                              }
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(72, 52),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            label: const Text(
                              'SENIOR20 (20%)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            onPressed: () => ref.read(checkoutSettingsProvider.notifier).setDiscount(20),
                          ),
                          ActionChip(
                            label: const Text(
                              'PROMO10 (10%)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            onPressed: () => ref.read(checkoutSettingsProvider.notifier).setDiscount(10),
                          ),
                          if (settings.discountPercent > 0)
                            ActionChip(
                              label: const Text(
                                'Clear',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              onPressed: () => ref.read(checkoutSettingsProvider.notifier).setDiscount(0),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TotalRow(label: 'Subtotal', value: '₱${totals.subtotal.toStringAsFixed(2)}'),
                      _TotalRow(
                        label: settings.vatMode == VatMode.inclusive ? 'Tax / VAT' : 'Tax (10% VAT)',
                        value: settings.vatMode == VatMode.inclusive
                            ? 'Inclusive in item price'
                            : '₱${totals.tax.toStringAsFixed(2)}',
                        muted: settings.vatMode == VatMode.inclusive,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Total Payable',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '₱${totals.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.restaurant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TutorialTarget(
                  anchor: TutorialAnchor.payButton,
                  child: FilledButton(
                    onPressed: cart.isEmpty ? null : _checkout,
                    style: FilledButton.styleFrom(
                      backgroundColor: cart.isEmpty ? AppColors.slate200 : AppColors.slate900,
                      foregroundColor: cart.isEmpty ? AppColors.slate400 : Colors.white,
                      minimumSize: const Size.fromHeight(64),
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      settings.paymentMethod == PaymentMethod.cash
                          ? 'Pay Cash & Calc Change (₱${totals.total.toStringAsFixed(2)}) →'
                          : 'Complete Order (${settings.paymentMethod.label})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.index, required this.line});

  final int index;
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => ref.read(cartProvider.notifier).removeAt(index),
                icon: const Icon(Icons.delete_outline, size: 16),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(
            '₱${line.product.price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              _QtyBtn(
                icon: Icons.remove,
                onTap: () {
                  try {
                    ref.read(cartProvider.notifier).updateQty(index, -1);
                  } catch (e) {
                    showAppError(context, e);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${line.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              _QtyBtn(
                icon: Icons.add,
                onTap: () {
                  try {
                    ref.read(cartProvider.notifier).updateQty(index, 1);
                  } catch (e) {
                    showAppError(context, e);
                  }
                },
              ),
              const Spacer(),
              Text(
                '₱${line.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayChip extends StatelessWidget {
  const _PayChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.slate900 : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.slate900 : AppColors.slate200),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: selected ? AppColors.retail : AppColors.slate700,
            ),
          ),
        ),
      ),
    );
  }
}

class _VatChip extends StatelessWidget {
  const _VatChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? selectedColor : AppColors.slate200),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: muted ? AppColors.success : AppColors.slate500)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: muted ? AppColors.success : AppColors.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
