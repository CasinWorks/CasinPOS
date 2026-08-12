import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:uuid/uuid.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/input/numeric_formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/product_photo.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import 'sku_generator.dart';

Future<RetailProduct?> showProductEditorSheet(
  BuildContext context, {
  RetailProduct? existing,
  String? initialCategory,
}) {
  return showModalBottomSheet<RetailProduct>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ProductEditorSheet(
      existing: existing,
      initialCategory: initialCategory,
    ),
  );
}

class _ProductEditorSheet extends ConsumerStatefulWidget {
  const _ProductEditorSheet({this.existing, this.initialCategory});

  final RetailProduct? existing;
  final String? initialCategory;

  @override
  ConsumerState<_ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends ConsumerState<_ProductEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _category;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late final TextEditingController _stock;
  late final TextEditingController _lowStock;
  late final TextEditingController _unit;
  late String _productId;
  String? _imageUrl;
  Uint8List? _previewBytes;
  String? _error;
  bool _uploading = false;
  /// Once the user edits SKU, stop overwriting it from the name.
  late bool _skuLocked;

  final _picker = ImagePicker();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _productId = e?.id ?? const Uuid().v4();
    _name = TextEditingController(text: e?.name ?? '');
    _sku = TextEditingController(text: e?.sku ?? '');
    _category = TextEditingController(
      text: e?.category ?? widget.initialCategory?.trim() ?? 'General',
    );
    _price = TextEditingController(text: (e?.price ?? 0).toStringAsFixed(2));
    _cost = TextEditingController(text: (e?.costPrice ?? 0).toStringAsFixed(2));
    _stock = TextEditingController(text: (e?.stock ?? 10).toStringAsFixed(0));
    _lowStock = TextEditingController(
      text: (e?.lowStockThreshold ?? 10).toStringAsFixed(0),
    );
    _unit = TextEditingController(text: e?.weight ?? 'Unit');
    _imageUrl = (e?.imageUrl.trim().isNotEmpty ?? false) ? e!.imageUrl : null;
    // New products auto-sync SKU; edits keep the existing SKU unless empty.
    _skuLocked = e != null && (e.sku.trim().isNotEmpty);
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (_skuLocked || !mounted) return;
    final existing = ref.read(posCatalogProvider)
        .where((p) => p.id != _productId)
        .map((p) => p.sku);
    final next = generateSkuFromName(_name.text, existingSkus: existing);
    if (_sku.text != next) {
      _sku.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  void _regenerateSku() {
    final existing = ref.read(posCatalogProvider)
        .where((p) => p.id != _productId)
        .map((p) => p.sku);
    final next = generateSkuFromName(_name.text, existingSkus: existing);
    setState(() {
      _skuLocked = false;
      _sku.text = next;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _category.dispose();
    _price.dispose();
    _cost.dispose();
    _stock.dispose();
    _lowStock.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null) {
      setState(() => _error = 'Sign in with a store to upload photos');
      return;
    }

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() {
        _uploading = true;
        _error = null;
      });

      final bytes = await file.readAsBytes();
      setState(() => _previewBytes = Uint8List.fromList(bytes));

      final mime = _mimeForName(file.name);
      final url = await ref.read(storeRepositoryProvider).uploadProductImage(
            storeId: membership.storeId,
            productId: _productId,
            bytes: bytes,
            contentType: mime,
          );

      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error =
            'Photo upload failed. Apply Script I (product-images bucket + storage RLS) in Supabase, then retry.';
      });
    }
  }

  String _mimeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _clearPhoto() {
    setState(() {
      _previewBytes = null;
      _imageUrl = null;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Product name is required');
      showAppMessage(context, 'Product name is required', isError: true);
      return;
    }
    if (_uploading) {
      setState(() => _error = 'Wait for the photo to finish uploading');
      showAppMessage(context, 'Wait for the photo to finish uploading', isError: true);
      return;
    }
    final price = NumericInput.tryParseMoney(_price.text);
    final cost = NumericInput.tryParseMoney(_cost.text);
    final stockInt = NumericInput.tryParseInt(_stock.text);
    final lowInt = NumericInput.tryParseInt(_lowStock.text);
    if (price == null || price < 0 || cost == null || cost < 0) {
      setState(() => _error = 'Enter valid price and cost');
      showAppMessage(context, 'Enter valid price and cost amounts', isError: true);
      return;
    }
    if (stockInt == null || stockInt < 0 || lowInt == null || lowInt < 0) {
      setState(() => _error = 'Enter valid stock values');
      showAppMessage(context, 'Enter valid stock quantity and low-stock alert', isError: true);
      return;
    }
    final stock = stockInt.toDouble();
    final low = lowInt.toDouble();

    final existing = widget.existing;
    final category = _category.text.trim().isEmpty ? 'General' : _category.text.trim();
    ref.read(catalogCategoriesProvider.notifier).ensure(category);

    final others = ref.read(posCatalogProvider).where((p) => p.id != _productId).map((p) => p.sku);
    final sku = _sku.text.trim().isEmpty
        ? generateSkuFromName(name, existingSkus: others)
        : _sku.text.trim().toUpperCase();

    final product = RetailProduct(
      id: _productId,
      sku: sku.isEmpty ? 'SKU-${DateTime.now().millisecondsSinceEpoch % 100000}' : sku,
      name: name,
      category: category,
      price: price,
      costPrice: cost,
      weight: _unit.text.trim().isEmpty ? 'Unit' : _unit.text.trim(),
      stock: stock,
      lowStockThreshold: low,
      imageUrl: _imageUrl ?? '',
      description: existing?.description ?? '',
      barcode: existing?.barcode,
    );
    Navigator.pop(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.slate200,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isEditing ? 'Edit Product' : 'Add Product',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      _isEditing
                          ? 'Update details, photo, then save to apply across POS & inventory'
                          : 'Create a catalog item with photo, price, and opening stock',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Stack(
                        children: [
                          ProductPhoto(
                            imageUrl: _imageUrl,
                            bytes: _previewBytes,
                            width: 120,
                            height: 120,
                            borderRadius: 20,
                            iconSize: 36,
                          ),
                          if (_uploading)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: Text(kIsWeb ? 'Choose file' : 'Gallery'),
                        ),
                        if (!kIsWeb)
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined, size: 16),
                            label: const Text('Camera'),
                          ),
                        if (_imageUrl != null || _previewBytes != null)
                          TextButton.icon(
                            onPressed: _uploading ? null : _clearPhoto,
                            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFE11D48)),
                            label: const Text('Remove', style: TextStyle(color: Color(0xFFE11D48))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        helperText: 'SKU updates automatically from the name',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sku,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) {
                        if (!_skuLocked) setState(() => _skuLocked = true);
                      },
                      decoration: InputDecoration(
                        labelText: 'SKU',
                        helperText: _skuLocked
                            ? 'Custom SKU — tap refresh to regenerate from name'
                            : 'Auto-generated — edit anytime to lock it',
                        suffixIcon: IconButton(
                          tooltip: 'Generate from name',
                          onPressed: _regenerateSku,
                          icon: const Icon(Icons.autorenew_rounded, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _category,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g. Bakery, Phone cases, Produce',
                        helperText: 'Type your own — tap a chip below to reuse one',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in ref.watch(productCategorySuggestionsProvider))
                            ActionChip(
                              label: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              onPressed: () => setState(() => _category.text = c),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _price,
                            keyboardType: NumericInput.moneyKeyboard,
                            inputFormatters: NumericInput.money(),
                            decoration: const InputDecoration(labelText: 'Retail price'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _cost,
                            keyboardType: NumericInput.moneyKeyboard,
                            inputFormatters: NumericInput.money(),
                            decoration: const InputDecoration(labelText: 'Cost price'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _stock,
                            keyboardType: NumericInput.integerKeyboard,
                            inputFormatters: NumericInput.integers,
                            decoration: const InputDecoration(labelText: 'Stock qty'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lowStock,
                            keyboardType: NumericInput.integerKeyboard,
                            inputFormatters: NumericInput.integers,
                            decoration: const InputDecoration(labelText: 'Low-stock alert'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unit (e.g. Unit, kg, pack)'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12)),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _uploading ? null : _save,
                            style: FilledButton.styleFrom(backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white),
                            child: Text(_isEditing ? 'Save changes' : 'Add product'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
