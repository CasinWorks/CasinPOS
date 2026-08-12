import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/product_photo.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../onboarding/tutorial_anchors.dart';
import 'barcode_scanner_sheet.dart';

class RetailPosView extends ConsumerStatefulWidget {
  const RetailPosView({super.key, required this.onOpenInventory});

  final VoidCallback onOpenInventory;

  @override
  ConsumerState<RetailPosView> createState() => _RetailPosViewState();
}

class _RetailPosViewState extends ConsumerState<RetailPosView> {
  String _category = 'All';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(posCatalogProvider);
    final categoryFilters = ref.watch(retailCategoryFiltersProvider);
    if (_category != 'All' && !categoryFilters.contains(_category)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _category = 'All');
      });
    }
    final store = ref.watch(activeMembershipProvider)?.store;
    final storeName = store?.name ?? 'Your Retail Store';
    final symbol = store?.currencySymbol ?? '₱';
    final q = _search.text.trim().toLowerCase();
    final filtered = products.where((p) {
      final matchesCat = _category == 'All' || p.category == _category;
      final matchesSearch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          (p.barcode?.contains(q) ?? false);
      return matchesCat && matchesSearch;
    }).toList();

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF151515), Color(0xFF3D2E00), Color(0xFF151515)],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandLogo(size: 40, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                storeName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tune_rounded, size: 12, color: AppColors.accent),
                                    SizedBox(width: 4),
                                    Text(
                                      'Retail POS · Your prices',
                                      style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan barcode / SKU or search products. Add items in Inventory — catalog starts empty.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onOpenInventory,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF334155)),
                        backgroundColor: const Color(0xFF1E293B),
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.success),
                      label: const Text('Store Inventory', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                    FilledButton.icon(
                      onPressed: () => openBarcodeScanner(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text('Scan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                    FilledButton.icon(
                      onPressed: () => ref.read(retailTabProvider.notifier).state = 'inventory',
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Scan barcode, SKU or product name...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: const Color(0xFFF1F1F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in categoryFilters) ...[
                  ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    selected: _category == cat,
                    selectedColor: AppColors.slate900,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    labelStyle: TextStyle(
                      color: _category == cat ? Colors.white : AppColors.slate700,
                    ),
                    onSelected: (_) => setState(() => _category = cat),
                    showCheckmark: false,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            TutorialTarget(
              anchor: TutorialAnchor.productArea,
              child: Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.slate300),
                  const SizedBox(height: 12),
                  Text(
                    products.isEmpty ? 'No products yet' : 'No products match this filter',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    products.isEmpty
                        ? 'Open Store Inventory → Add Product to build your catalog with your own prices ($symbol).'
                        : 'Try another category or clear search.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: widget.onOpenInventory,
                    child: const Text('Go to Inventory'),
                  ),
                ],
              ),
            ),
            )
          else
            TutorialTarget(
              anchor: TutorialAnchor.productArea,
              child: LayoutBuilder(
              builder: (context, constraints) {
                // Tablet POS: prefer denser tiles so more SKUs fit without huge scrolling.
                final w = constraints.maxWidth;
                final cols = w >= 1100
                    ? 5
                    : w >= 820
                        ? 4
                        : w >= 520
                            ? 3
                            : 2;
                final aspect = w >= 820 ? 0.78 : 0.72;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: aspect,
                  ),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final inCart = ref.watch(
                      cartProvider.select(
                        (cart) => cart
                            .where((l) => l.product.id == p.id)
                            .fold<int>(0, (s, l) => s + l.quantity),
                      ),
                    );
                    final remaining = (p.stock - inCart).clamp(0, 999999);
                    final out = remaining <= 0;
                    return _ProductCard(
                      product: p,
                      currencySymbol: symbol,
                      outOfStock: out,
                      remaining: remaining.toDouble(),
                      onAdd: () {
                        try {
                          ref.read(cartProvider.notifier).add(p);
                        } catch (e) {
                          showAppError(context, e);
                        }
                      },
                    );
                  },
                );
              },
            ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.product,
    required this.onAdd,
    this.currencySymbol = '₱',
    this.outOfStock = false,
    this.remaining = 0,
  });

  final RetailProduct product;
  final VoidCallback onAdd;
  final String currencySymbol;
  final bool outOfStock;
  final double remaining;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> with SingleTickerProviderStateMixin {
  late final AnimationController _tapPulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _tapPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 0.94), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.03), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1), weight: 30),
    ]).animate(CurvedAnimation(parent: _tapPulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _tapPulse.dispose();
    super.dispose();
  }

  void _handleAdd() {
    if (widget.outOfStock) return;
    _tapPulse.forward(from: 0);
    widget.onAdd();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final outOfStock = widget.outOfStock;
    final remaining = widget.remaining;
    final currencySymbol = widget.currencySymbol;

    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: outOfStock
            ? const Color(0xFFF8FAFC)
            : product.isLowStock
                ? const Color(0xFFFFFBEB)
                : AppColors.scaffold,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _handleAdd,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: outOfStock ? 0.72 : 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: outOfStock
                      ? AppColors.slate200
                      : product.isLowStock
                          ? const Color(0xFFFCD34D)
                          : AppColors.slate100,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ProductPhoto(
                            imageUrl: product.imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 12,
                            iconSize: 28,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.slate900.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: product.isOnSale
                                    ? const Color(0xFFF97316)
                                    : AppColors.retail.withValues(alpha: 0.55),
                              ),
                            ),
                            child: product.isOnSale
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$currencySymbol${product.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.65),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$currencySymbol${product.effectivePrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Color(0xFFFDBA74),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    '$currencySymbol${product.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: AppColors.retail,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                          ),
                        ),
                        if (product.isOnSale)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'SALE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        if (outOfStock)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'OUT OF STOCK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Opacity(
                    opacity: 0.55,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.sku,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate500,
                            ),
                          ),
                        ),
                        if (product.weight.trim().isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.weight,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                        ],
                        if (product.category.trim().isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              product.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          outOfStock
                              ? 'No units left'
                              : '${remaining.toStringAsFixed(0)} left',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: outOfStock
                                ? const Color(0xFFE11D48)
                                : product.isLowStock
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFF047857),
                          ),
                        ),
                      ),
                      if (!outOfStock && product.isLowStock)
                        const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFF59E0B)),
                        ),
                      FilledButton(
                        onPressed: outOfStock ? null : _handleAdd,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.slate900,
                          foregroundColor: AppColors.retail,
                          disabledBackgroundColor: AppColors.slate300,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(64, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        child: Text(outOfStock ? 'Sold' : '+ Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
