import 'dart:async';

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
  var _stylePromptScheduled = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _maybePromptCatalogStyle() async {
    if (!mounted) return;
    final notifier = ref.read(posShowProductImagesProvider.notifier);
    final shouldAsk = await notifier.shouldPromptStyleChoice();
    if (!shouldAsk || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('How should products look?'),
        content: const Text(
          'For clearer checkout — especially for older cashiers — '
          'you can hide photos and show large names and prices only.\n\n'
          'You can switch anytime with Photos / Text only next to the categories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keep photos'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Text only (easier to read)'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == null) {
      await notifier.markStyleAsked();
      return;
    }
    await notifier.setShowImages(choice);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(posCatalogProvider);
    final showImages = ref.watch(posShowProductImagesProvider);
    final categoryFilters = ref.watch(retailCategoryFiltersProvider);
    if (_category != 'All' && !categoryFilters.contains(_category)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _category = 'All');
      });
    }
    if (!_stylePromptScheduled) {
      _stylePromptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybePromptCatalogStyle());
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Scan barcode, SKU or product name...',
              hintStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              prefixIcon: const Icon(Icons.search, size: 22),
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
                FilterChip(
                  avatar: Icon(
                    showImages ? Icons.image_outlined : Icons.text_fields_rounded,
                    size: 18,
                    color: showImages ? AppColors.slate700 : Colors.white,
                  ),
                  label: Text(showImages ? 'Photos' : 'Text only'),
                  selected: !showImages,
                  selectedColor: AppColors.slate900,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: showImages ? AppColors.slate800 : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  onSelected: (_) {
                    ref
                        .read(posShowProductImagesProvider.notifier)
                        .setShowImages(!showImages);
                  },
                ),
                const SizedBox(width: 10),
                for (final cat in categoryFilters) ...[
                  ChoiceChip(
                    label: Text(cat),
                    selected: _category == cat,
                    selectedColor: AppColors.slate900,
                    labelStyle: TextStyle(
                      color: _category == cat ? Colors.white : AppColors.slate800,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
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
                final w = constraints.maxWidth;
                // Dense grid so cashiers see many products without long scrolling.
                final cols = showImages
                    ? (w >= 1000
                        ? 4
                        : w >= 700
                            ? 3
                            : w >= 480
                                ? 2
                                : 1)
                    : (w >= 1000
                        ? 4
                        : w >= 680
                            ? 3
                            : 2);
                // Shorter tiles = more rows on screen; still room for photo + readable type.
                final aspect = showImages
                    ? (w >= 900 ? 0.92 : 0.88)
                    : (w >= 900 ? 1.55 : 1.35);
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
                      showImage: showImages,
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
    this.showImage = true,
  });

  final RetailProduct product;
  final VoidCallback onAdd;
  final String currencySymbol;
  final bool outOfStock;
  final double remaining;
  final bool showImage;

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
    final showImage = widget.showImage;

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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: outOfStock
                      ? AppColors.slate200
                      : product.isLowStock
                          ? const Color(0xFFFCD34D)
                          : AppColors.slate100,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showImage)
                    Expanded(
                      flex: 6,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ProductPhoto(
                              imageUrl: product.imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: 10,
                              fit: BoxFit.cover,
                              iconSize: 28,
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
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          if (outOfStock)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text(
                                    'OUT OF STOCK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else if (product.isOnSale || outOfStock)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          if (product.isOnSale)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'SALE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (outOfStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'OUT OF STOCK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (showImage) const SizedBox(height: 6),
                  Expanded(
                    flex: showImage ? 4 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          product.name,
                          maxLines: showImage ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: showImage ? 15 : 17,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currencySymbol${product.effectivePrice.toStringAsFixed(0)}',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: showImage ? 22 : 26,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: product.isOnSale
                                ? const Color(0xFFC2410C)
                                : AppColors.slate900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (product.isOnSale)
                          Text(
                            '$currencySymbol${product.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate500.withValues(alpha: 0.9),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                outOfStock
                                    ? 'No stock'
                                    : '${remaining.toStringAsFixed(0)} left',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: outOfStock
                                      ? const Color(0xFFE11D48)
                                      : product.isLowStock
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF047857),
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: outOfStock ? null : _handleAdd,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.slate900,
                                foregroundColor: AppColors.retail,
                                disabledBackgroundColor: AppColors.slate300,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                minimumSize: const Size(64, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                              child: Text(outOfStock ? 'Sold' : '+ Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
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
