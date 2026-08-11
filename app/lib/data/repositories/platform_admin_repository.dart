import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap.dart';
import '../../core/config/app_url.dart';
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

  Future<List<PlatformSupportNote>> listSupportNotes(String storeId) async {
    final res = await _client.rpc(
      'platform_list_support_notes',
      params: {'p_store_id': storeId},
    );
    final notes = (res is Map ? res['notes'] : null);
    if (notes is! List) return const [];
    return notes
        .whereType<Map>()
        .map((e) => PlatformSupportNote.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addSupportNote({
    required String storeId,
    required String body,
  }) async {
    final res = await _client.rpc(
      'platform_add_support_note',
      params: {
        'p_store_id': storeId,
        'p_body': body.trim(),
      },
    );
    if (res is Map && res['ok'] == true) return;
    throw AppException(friendlyError(res ?? 'Could not save note'));
  }

  Future<List<PlatformStoreMessage>> listStoreMessagesAdmin(String storeId) async {
    final res = await _client.rpc(
      'platform_list_store_messages',
      params: {'p_store_id': storeId},
    );
    final messages = (res is Map ? res['messages'] : null);
    if (messages is! List) return const [];
    return messages
        .whereType<Map>()
        .map((e) => PlatformStoreMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> sendStoreMessage({
    required String storeId,
    required String subject,
    required String body,
  }) async {
    final res = await _client.rpc(
      'platform_send_store_message',
      params: {
        'p_store_id': storeId,
        'p_subject': subject.trim(),
        'p_body': body.trim(),
      },
    );
    if (res is Map && res['ok'] == true) return;
    throw AppException(friendlyError(res ?? 'Could not send message'));
  }

  Future<List<PlatformStoreMessage>> listMyStoreMessages(String storeId) async {
    final res = await _client.rpc(
      'list_my_store_messages',
      params: {'p_store_id': storeId},
    );
    final messages = (res is Map ? res['messages'] : null);
    if (messages is! List) return const [];
    return messages
        .whereType<Map>()
        .map((e) => PlatformStoreMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markStoreMessageRead(String messageId) async {
    final res = await _client.rpc(
      'mark_store_message_read',
      params: {'p_message_id': messageId},
    );
    if (res is Map && res['ok'] == true) return;
    throw AppException(friendlyError(res ?? 'Could not mark read'));
  }

  Future<PlatformResetPasswordResult> sendOwnerPasswordReset({
    required String storeId,
    String? email,
    String? userId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'platform-reset-password',
        body: {
          'store_id': storeId,
          'email': email?.trim().isNotEmpty == true ? email!.trim().toLowerCase() : null,
          'user_id': userId,
          'redirect_to': AppUrl.resetPasswordLink(),
        },
      );
      final data = res.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      if (res.status >= 400) {
        throw AppException(
          friendlyError(map['message'] ?? map['error'] ?? 'Reset failed'),
        );
      }
      return PlatformResetPasswordResult(
        ok: map['ok'] == true,
        emailed: map['emailed'] == true,
        email: map['email'] as String?,
        resetUrl: map['reset_url'] as String?,
        message: map['message'] as String?,
        reason: map['reason'] as String?,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }
}
