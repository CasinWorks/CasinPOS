import 'dart:convert';

import 'local_pos_kv_io.dart' if (dart.library.html) 'local_pos_kv_web.dart' as kv;

/// Durable on-device POS cache (file on iOS/Android, localStorage on web).
abstract final class LocalPosStore {
  static String _k(String storeId, String leaf) => 'casinpos:$storeId:$leaf';

  static Future<void> saveCatalog(String storeId, List<Map<String, dynamic>> products) async {
    await kv.write(_k(storeId, 'catalog'), jsonEncode(products));
  }

  static Future<List<Map<String, dynamic>>> loadCatalog(String storeId) async {
    final raw = await kv.read(_k(storeId, 'catalog'));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded.whereType<Map>()) Map<String, dynamic>.from(e),
    ];
  }

  static Future<void> saveOrders(String storeId, List<Map<String, dynamic>> orders) async {
    await kv.write(_k(storeId, 'orders'), jsonEncode(orders));
  }

  static Future<List<Map<String, dynamic>>> loadOrders(String storeId) async {
    final raw = await kv.read(_k(storeId, 'orders'));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded.whereType<Map>()) Map<String, dynamic>.from(e),
    ];
  }

  static Future<void> saveRegister(String storeId, Map<String, dynamic> register) async {
    await kv.write(_k(storeId, 'register'), jsonEncode(register));
  }

  static Future<Map<String, dynamic>?> loadRegister(String storeId) async {
    final raw = await kv.read(_k(storeId, 'register'));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> clearRegister(String storeId) async {
    await kv.remove(_k(storeId, 'register'));
  }

  static Future<List<Map<String, dynamic>>> loadOutbox(String storeId) async {
    final raw = await kv.read(_k(storeId, 'outbox'));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded.whereType<Map>()) Map<String, dynamic>.from(e),
    ];
  }

  static Future<void> saveOutbox(String storeId, List<Map<String, dynamic>> items) async {
    await kv.write(_k(storeId, 'outbox'), jsonEncode(items));
  }

  static Future<void> enqueueOutbox(String storeId, Map<String, dynamic> item) async {
    final current = await loadOutbox(storeId);
    await saveOutbox(storeId, [...current, item]);
  }

  static Future<void> removeOutboxId(String storeId, String id) async {
    final current = await loadOutbox(storeId);
    await saveOutbox(storeId, [for (final i in current) if (i['id'] != id) i]);
  }

  static Future<void> saveDiscountCodes(
    String storeId,
    List<Map<String, dynamic>> codes,
  ) async {
    await kv.write(_k(storeId, 'discount_codes'), jsonEncode(codes));
  }

  static Future<List<Map<String, dynamic>>> loadDiscountCodes(String storeId) async {
    final raw = await kv.read(_k(storeId, 'discount_codes'));
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded.whereType<Map>()) Map<String, dynamic>.from(e),
    ];
  }
}
