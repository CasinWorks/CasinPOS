import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap.dart';
import '../../core/errors/app_errors.dart';
import '../../domain/enums.dart';
import '../models/platform_models.dart';

class PlatformAdminRepository {
  SupabaseClient get _client {
    final c = supabaseOrNull;
    if (c == null) throw StateError('Supabase is not initialized.');
    return c;
  }

  Future<bool> amIPlatformAdmin() async {
    try {
      final res = await _client.rpc('is_platform_admin');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<PlatformTenant>> listTenants({String? search}) async {
    final res = await _client.rpc(
      'platform_list_tenants',
      params: {'p_search': search?.trim().isEmpty == true ? null : search?.trim()},
    );
    final rows = res is List
        ? res
        : res is Map
            ? [res]
            : const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((e) => PlatformTenant.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setStorePlan({
    required String storeId,
    required PlanTier plan,
    int? monthlyLimit,
  }) async {
    final res = await _client.rpc(
      'platform_set_store_plan',
      params: {
        'p_store_id': storeId,
        'p_plan_tier': plan.value,
        'p_monthly_limit': monthlyLimit,
      },
    );
    if (res is Map && res['ok'] == true) return;
    throw AppException(friendlyError(res ?? 'Could not update plan'));
  }

  Future<void> setStoreSuspended({
    required String storeId,
    required bool suspended,
    String? reason,
  }) async {
    final res = await _client.rpc(
      'platform_set_store_suspended',
      params: {
        'p_store_id': storeId,
        'p_suspended': suspended,
        'p_reason': reason,
      },
    );
    if (res is Map && res['ok'] == true) return;
    throw AppException(friendlyError(res ?? 'Could not update suspension'));
  }

  Future<void> promoteAdminByEmail(String email, {bool isAdmin = true}) async {
    final res = await _client.rpc(
      'platform_set_admin_by_email',
      params: {
        'p_email': email.trim(),
        'p_is_admin': isAdmin,
      },
    );
    if (res is Map && res['ok'] == true) return;
    throw AppException(friendlyError(res ?? 'Could not update admin flag'));
  }
}
