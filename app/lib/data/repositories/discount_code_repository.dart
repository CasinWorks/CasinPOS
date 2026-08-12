import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../bootstrap.dart';
import '../../core/errors/app_errors.dart';
import '../models/pos_models.dart';

class DiscountCodeRepository {
  SupabaseClient get _client {
    final c = supabaseOrNull;
    if (c == null) {
      throw StateError('Supabase is not initialized.');
    }
    return c;
  }

  Future<List<DiscountCode>> listForStore(String storeId) async {
    final rows = await _client
        .from('discount_codes')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => _fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DiscountCode> upsert(DiscountCode code) async {
    final normalized = code.code.trim().toUpperCase();
    if (normalized.length < 2) {
      throw AppException('Enter a discount code (at least 2 characters).');
    }
    if (code.value <= 0) {
      throw AppException('Discount value must be greater than zero.');
    }
    if (code.kind == DiscountKind.percent && code.value > 100) {
      throw AppException('Percent discount cannot exceed 100%.');
    }

    final id = code.id.trim().isEmpty ? const Uuid().v4() : code.id;
    final row = await _client
        .from('discount_codes')
        .upsert({
          'id': id,
          'store_id': code.storeId,
          'code': normalized,
          'kind': code.kind.name,
          'value': code.value,
          'is_active': code.isActive,
          'starts_at': code.startsAt?.toUtc().toIso8601String(),
          'ends_at': code.endsAt?.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return _fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> delete(String id) async {
    await _client.from('discount_codes').delete().eq('id', id);
  }

  DiscountCode _fromRow(Map<String, dynamic> json) {
    final kindRaw = (json['kind'] as String? ?? 'percent').toLowerCase();
    return DiscountCode(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      kind: kindRaw == 'fixed' ? DiscountKind.fixed : DiscountKind.percent,
      value: (json['value'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? ''),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
    );
  }
}
