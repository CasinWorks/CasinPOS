import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap.dart';
import '../cart_display_sync.dart';

class CustomerDisplayRepository {
  SupabaseClient get _client {
    final c = supabaseOrNull;
    if (c == null) {
      throw StateError('Supabase is not initialized.');
    }
    return c;
  }

  Future<void> upsertSnapshot({
    required String storeId,
    required CartDisplaySnapshot snapshot,
  }) async {
    await _client.from('customer_display_snapshots').upsert({
      'store_id': storeId,
      'snapshot': snapshot.toJson(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': _client.auth.currentUser?.id,
    });
  }

  Future<CartDisplaySnapshot?> fetchSnapshot(String storeId) async {
    final row = await _client
        .from('customer_display_snapshots')
        .select('snapshot')
        .eq('store_id', storeId)
        .maybeSingle();
    if (row == null) return null;
    final raw = row['snapshot'];
    if (raw is Map) {
      return CartDisplaySnapshot.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String) {
      return CartDisplaySnapshot.tryParse(raw);
    }
    return null;
  }
}
