import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap.dart';
import '../models/pos_models.dart';

class ProductRepository {
  SupabaseClient get _client {
    final c = supabaseOrNull;
    if (c == null) {
      throw StateError('Supabase is not initialized.');
    }
    return c;
  }

  Future<List<RetailProduct>> fetchRetailProducts(String storeId) async {
    final rows = await _client
        .from('products')
        .select('*, categories(name)')
        .eq('store_id', storeId)
        .eq('kind', 'retail_sku')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => _fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String?> ensureCategoryId({
    required String storeId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final existing = await _client
        .from('categories')
        .select('id')
        .eq('store_id', storeId)
        .eq('name', trimmed)
        .maybeSingle();
    if (existing != null) {
      return existing['id'] as String;
    }

    final inserted = await _client
        .from('categories')
        .insert({
          'store_id': storeId,
          'name': trimmed,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  Future<RetailProduct> upsertRetailProduct({
    required String storeId,
    required RetailProduct product,
  }) async {
    final categoryId = await ensureCategoryId(
      storeId: storeId,
      name: product.category,
    );

    final payload = <String, dynamic>{
      'id': product.id,
      'store_id': storeId,
      'category_id': categoryId,
      'kind': 'retail_sku',
      'name': product.name.trim(),
      'sku': product.sku.trim().isEmpty ? null : product.sku.trim(),
      'barcode': product.barcode,
      'description': product.description,
      'image_path': product.imageUrl.trim().isEmpty ? null : product.imageUrl.trim(),
      'price': product.price,
      'cost_price': product.costPrice,
      'weight_label': product.weight,
      'stock': product.stock,
      'low_stock_threshold': product.lowStockThreshold,
      'sale_price': product.salePrice,
      'sale_starts_at': product.saleStartsAt?.toUtc().toIso8601String(),
      'sale_ends_at': product.saleEndsAt?.toUtc().toIso8601String(),
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await _client
        .from('products')
        .upsert(payload)
        .select('*, categories(name)')
        .single();

    return _fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> updateStock({
    required String productId,
    required double stock,
  }) async {
    await _client.from('products').update({
      'stock': stock,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productId);
  }

  Future<void> deleteProduct(String productId) async {
    await _client.from('products').update({
      'is_active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productId);
  }

  RetailProduct _fromRow(Map<String, dynamic> json) {
    final categoryJoin = json['categories'];
    String category = 'General';
    if (categoryJoin is Map) {
      category = (categoryJoin['name'] as String?)?.trim().isNotEmpty == true
          ? categoryJoin['name'] as String
          : 'General';
    }

    return RetailProduct(
      id: json['id'] as String,
      sku: (json['sku'] as String?) ?? '',
      name: json['name'] as String,
      category: category,
      price: _num(json['price']),
      costPrice: _num(json['cost_price']),
      weight: (json['weight_label'] as String?) ?? 'Unit',
      stock: _num(json['stock']),
      lowStockThreshold: _num(json['low_stock_threshold'], fallback: 10),
      imageUrl: (json['image_path'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      barcode: json['barcode'] as String?,
      salePrice: json['sale_price'] == null ? null : _num(json['sale_price']),
      saleStartsAt: DateTime.tryParse(json['sale_starts_at'] as String? ?? ''),
      saleEndsAt: DateTime.tryParse(json['sale_ends_at'] as String? ?? ''),
    );
  }

  double _num(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }
}
