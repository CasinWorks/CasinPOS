import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/product_photo.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../onboarding/tutorial_anchors.dart';
import 'product_editor_sheet.dart';

class RetailInventoryView extends ConsumerStatefulWidget {
  const RetailInventoryView({super.key});

  @override
  ConsumerState<RetailInventoryView> createState() => _RetailInventoryViewState();
}

class _RetailInventoryViewState extends ConsumerState<RetailInventoryView> {
  String _category = 'All';
  bool _lowOnly = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Produce, Electronics, Cosmetics',
            helperText: 'Add a product next — filters only list categories in inventory',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true && name.isNotEmpty && mounted) {
      ref.read(catalogCategoriesProvider.notifier).add(name);
      await _addProduct(prefillCategory: name);
    }
  }

  Future<void> _addProduct({String? prefillCategory}) async {
    final product = await showProductEditorSheet(
      context,
      initialCategory: prefillCategory,
    );
    if (product == null || !mounted) return;
    try {
      final saved = await ref.read(posCatalogProvider.notifier).addProduct(product);
      if (!mounted) return;
      setState(() => _category = saved.category);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.name} saved to store'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save product: ${friendlyError(e)}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _editProduct(RetailProduct product) async {
    final updated = await showProductEditorSheet(context, existing: product);
    if (updated == null || !mounted) return;
    try {
      final saved = await ref.read(posCatalogProvider.notifier).updateProduct(updated);
      ref.read(cartProvider.notifier).syncProduct(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.name} saved'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update product: ${friendlyError(e)}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _deleteProduct(RetailProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete product?'),
        content: Text(
          'Remove “${product.name}” from store inventory? This also clears it from the cart.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(posCatalogProvider.notifier).removeProduct(product.id);
      ref.read(cartProvider.notifier).removeProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} deleted'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        e,
        fallback: 'Could not delete this product. Check your connection and try again.',
      );
    }
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
    final q = _search.text.trim().toLowerCase();
    final filtered = products.where((p) {
      final matchesCat = _category == 'All' || p.category == _category;
      final matchesSearch =
          q.isEmpty || p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q);
      final matchesLow = !_lowOnly || p.isLowStock;
      return matchesCat && matchesSearch && matchesLow;
    }).toList();

    final totalStock = products.fold<double>(0, (s, p) => s + p.stock);
    final valuation = products.fold<double>(0, (s, p) => s + p.stock * p.price);

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.restaurant),
                        SizedBox(width: 6),
                        Text(
                          'Store Inventory',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Text(
                      'Track stock, cost & retail prices — edit or delete anytime',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              TutorialTarget(
                anchor: TutorialAnchor.addProductBtn,
                child: FilledButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrowStats = constraints.maxWidth < Breakpoints.phoneMax;
              final cards = [
                _StatCard(label: 'Total Products Tracked', value: '${products.length} Items'),
                _StatCard(label: 'Total Units in Stock', value: '${totalStock.toStringAsFixed(0)} Units'),
                _StatCard(
                  label: 'Total Inventory Retail Value',
                  value: '₱${valuation.toStringAsFixed(2)}',
                  valueColor: AppColors.restaurant,
                ),
              ];
              if (narrowStats) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: cards[i]),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackedFilters = constraints.maxWidth < 420;
              final search = TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search product name or SKU...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF1F1F1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              );
              final lowChip = FilterChip(
                label: const Text('Low Stock Only', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                selected: _lowOnly,
                avatar: const Icon(Icons.warning_amber_rounded, size: 14),
                selectedColor: const Color(0xFFF43F5E),
                labelStyle: TextStyle(color: _lowOnly ? Colors.white : AppColors.slate600),
                onSelected: (v) => setState(() => _lowOnly = v),
                showCheckmark: false,
              );
              if (stackedFilters) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: lowChip),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 8),
                  lowChip,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in categoryFilters) ...[
                  ChoiceChip(
                    label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    selected: _category == cat,
                    selectedColor: AppColors.slate900,
                    labelStyle: TextStyle(color: _category == cat ? Colors.white : AppColors.slate600),
                    onSelected: (_) => setState(() => _category = cat),
                    showCheckmark: false,
                  ),
                  const SizedBox(width: 6),
                ],
                ActionChip(
                  avatar: const Icon(Icons.add, size: 14),
                  label: const Text('New category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  onPressed: _addCategory,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  products.isEmpty ? 'No products yet — add your first item' : 'No products match your filters',
                  style: const TextStyle(color: AppColors.slate400, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          for (final p in filtered)
            _InventoryProductCard(
              product: p,
              onEdit: () => _editProduct(p),
              onDelete: () => _deleteProduct(p),
              onRestock: (delta) => ref.read(posCatalogProvider.notifier).restock(p.id, delta),
            ),
        ],
      ),
    );
  }
}

class _InventoryProductCard extends StatelessWidget {
  const _InventoryProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onRestock,
  });

  final RetailProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(double delta) onRestock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < Breakpoints.phoneMax;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onEdit,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: product.isLowStock ? const Color(0xFFFFF1F2) : AppColors.scaffold,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: product.isLowStock ? const Color(0xFFFECDD3) : AppColors.slate200,
                ),
              ),
              child: compact ? _buildCompact() : _buildWide(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photo(),
            const SizedBox(width: 12),
            Expanded(child: _infoColumn()),
            const SizedBox(width: 8),
            _stockBadge(crossAxisAlignment: CrossAxisAlignment.end),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _editButton(),
            _deleteButton(),
            _minusButton(),
            _plusTenButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildWide() {
    return Row(
      children: [
        _photo(),
        const SizedBox(width: 12),
        Expanded(child: _infoColumn()),
        const SizedBox(width: 12),
        _stockBadge(crossAxisAlignment: CrossAxisAlignment.end),
        const SizedBox(width: 6),
        _editButton(),
        _deleteButton(),
        _minusButton(),
        const SizedBox(width: 6),
        _plusTenButton(),
      ],
    );
  }

  Widget _photo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ProductPhoto(
        imageUrl: product.imageUrl,
        width: 48,
        height: 48,
        borderRadius: 12,
        iconSize: 20,
      ),
    );
  }

  Widget _infoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        Text(
          'SKU ${product.sku} · Cost ₱${product.costPrice.toStringAsFixed(0)} · Retail ₱${product.price.toStringAsFixed(0)}'
          '${product.isOnSale ? ' · Sale ₱${product.effectivePrice.toStringAsFixed(0)}' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.slate500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          'Tap to edit',
          style: TextStyle(fontSize: 9, color: AppColors.slate400),
        ),
      ],
    );
  }

  Widget _stockBadge({required CrossAxisAlignment crossAxisAlignment}) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${product.stock.toStringAsFixed(0)} in stock',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: product.isLowStock ? const Color(0xFFE11D48) : AppColors.ink,
              ),
            ),
            if (product.isLowStock)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Color(0xFFF59E0B),
                ),
              ),
          ],
        ),
        Text(
          'Alert @ ≤${product.lowStockThreshold.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 9, color: AppColors.slate400),
        ),
      ],
    );
  }

  Widget _editButton() {
    return IconButton(
      tooltip: 'Edit',
      onPressed: onEdit,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        iconSize: 22,
      ),
      icon: const Icon(Icons.edit_outlined),
    );
  }

  Widget _deleteButton() {
    return IconButton(
      tooltip: 'Delete',
      onPressed: onDelete,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        iconSize: 22,
      ),
      icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48)),
    );
  }

  Widget _minusButton() {
    return IconButton.filledTonal(
      onPressed: () => onRestock(-1),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: const Icon(Icons.remove, size: 22),
    );
  }

  Widget _plusTenButton() {
    return FilledButton(
      onPressed: () => onRestock(10),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      child: const Text('+10'),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.slate400,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: valueColor ?? AppColors.ink),
          ),
        ],
      ),
    );
  }
}
