import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap.dart';
import '../../core/errors/app_errors.dart';
import '../../core/invite/invite_token.dart';
import '../../domain/enums.dart';
import '../models/store_models.dart';
import '../models/team_models.dart';

class InviteEmailResult {
  const InviteEmailResult({
    required this.emailed,
    this.inviteUrl,
    this.reason,
    this.message,
  });

  final bool emailed;
  final String? inviteUrl;
  final String? reason;
  final String? message;
}

class AuthRepository {
  SupabaseClient get _client {
    final c = supabaseOrNull;
    if (c == null) {
      throw StateError('Supabase is not initialized. Pass SUPABASE_URL and SUPABASE_ANON_KEY.');
    }
    return c;
  }

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    final c = supabaseOrNull;
    if (c == null) return;
    await c.auth.signOut();
  }

  /// Sends a password-reset email. [redirectTo] must be allow-listed in Supabase Auth.
  Future<void> resetPasswordForEmail({
    required String email,
    required String redirectTo,
  }) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}

class StoreRepository {
  SupabaseClient get _client {
    final c = supabaseOrNull;
    if (c == null) {
      throw StateError('Supabase is not initialized.');
    }
    return c;
  }

  Future<List<StoreMembership>> fetchMemberships() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await _client
        .from('store_members')
        .select('id, store_id, role, stores(*)')
        .eq('user_id', uid)
        .eq('status', 'active');

    return (rows as List)
        .map((e) => StoreMembership.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> createStore({
    required String name,
    required BusinessType businessType,
    String currencyCode = 'PHP',
    String currencySymbol = '₱',
  }) async {
    final result = await _client.rpc(
      'create_store',
      params: {
        'p_name': name.trim(),
        'p_business_type': businessType.value,
        'p_currency_code': currencyCode,
        'p_currency_symbol': currencySymbol,
        'p_primary_branch_name': 'Main',
      },
    );
    return result as String;
  }

  /// Creates a store invite, or resends if a pending invite already exists.
  /// Returns invitation fields including `token` and `resent` (bool).
  Future<Map<String, dynamic>> createInvitation({
    required String storeId,
    required String email,
    required StoreRole role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final result = await _client.rpc(
        'create_store_invitation',
        params: {
          'p_store_id': storeId,
          'p_email': normalizedEmail,
          'p_role': role.value,
          'p_branch_ids': null,
        },
      );
      final map = Map<String, dynamic>.from(result as Map);
      map['resent'] = map['resent'] == true;
      return map;
    } on PostgrestException catch (e) {
      // Fallback when RPC not yet migrated: unique pending (store_id, email).
      if (_isPendingInviteUniqueViolation(e)) {
        final existing = await _fetchPendingInvitation(
          storeId: storeId,
          email: normalizedEmail,
        );
        if (existing != null) {
          existing['resent'] = true;
          return existing;
        }
      }
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not send invite. Please try again.',
        cause: e,
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchPendingInvitation({
    required String storeId,
    required String email,
  }) async {
    final rows = await _client
        .from('store_invitations')
        .select()
        .eq('store_id', storeId)
        .eq('email', email)
        .eq('status', 'pending')
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  static bool _isPendingInviteUniqueViolation(PostgrestException e) {
    final code = e.code ?? '';
    final blob = '${e.message} ${e.details} ${e.hint} $code';
    return code == '23505' ||
        blob.contains('store_invitations_pending_unique') ||
        (blob.contains('duplicate key') && blob.contains('store_invitations'));
  }

  /// Calls Edge Function `send-invite-email` (Resend). Never throws — returns status.
  Future<InviteEmailResult> sendInviteEmail({
    required String email,
    required String token,
    String? storeName,
    String? role,
    String? inviteUrl,
    String? inviterName,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'send-invite-email',
        body: {
          'email': email.trim().toLowerCase(),
          'token': token.trim(),
          'store_name': ?storeName?.trim().isNotEmpty == true
              ? storeName!.trim()
              : null,
          'role': ?role,
          'invite_url': ?inviteUrl,
          'inviter_name': ?inviterName?.trim().isNotEmpty == true
              ? inviterName!.trim()
              : null,
        },
      );
      final data = res.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final emailed = map['emailed'] == true;
      return InviteEmailResult(
        emailed: emailed,
        inviteUrl: map['invite_url'] as String?,
        reason: map['reason'] as String?,
        message: map['message'] as String? ?? map['error'] as String?,
      );
    } catch (e) {
      return InviteEmailResult(
        emailed: false,
        reason: 'INVOKE_FAILED',
        message: e.toString(),
      );
    }
  }

  Future<StoreTeamSnapshot> listStoreTeam(String storeId) async {
    try {
      final result = await _client.rpc(
        'list_store_team',
        params: {'p_store_id': storeId},
      );
      return StoreTeamSnapshot.fromJson(Map<String, dynamic>.from(result as Map));
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not load team. Please try again.',
        cause: e,
      );
    }
  }

  Future<void> updateMemberRole({
    required String memberId,
    required StoreRole role,
  }) async {
    try {
      await _client.rpc(
        'update_store_member_role',
        params: {
          'p_member_id': memberId,
          'p_role': role.value,
        },
      );
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not change role. Please try again.',
        cause: e,
      );
    }
  }

  Future<void> removeMember(String memberId) async {
    try {
      await _client.rpc(
        'remove_store_member',
        params: {'p_member_id': memberId},
      );
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not remove member. Please try again.',
        cause: e,
      );
    }
  }

  Future<void> revokeInvitation(String invitationId) async {
    try {
      await _client.rpc(
        'revoke_store_invitation',
        params: {'p_invitation_id': invitationId},
      );
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not revoke invite. Please try again.',
        cause: e,
      );
    }
  }

  Future<String> acceptInvitation(String token) async {
    if (isInviteUrlMissingToken(token)) {
      throw AppException(kInviteMissingTokenMessage);
    }
    final cleaned = sanitizeInviteToken(token);
    if (cleaned == null || cleaned.length < 8) {
      throw AppException(
        'Invite not found. Check the link/token, or ask your store owner to resend it.',
      );
    }
    try {
      final result = await _client.rpc(
        'accept_store_invitation',
        params: {'p_token': cleaned},
      );
      return result as String;
    } catch (e) {
      throw AppException(
        friendlyError(
          e,
          fallback: 'Could not accept invite. Please try again.',
        ),
        cause: e,
      );
    }
  }

  /// Opens a franchise as a linked child store with a cloned catalog.
  Future<FranchiseCreateResult> createFranchiseStore({
    required String franchisorStoreId,
    required String ownerEmail,
    required String storeName,
    bool copyStock = true,
    num defaultStock = 0,
    String? notes,
  }) async {
    try {
      final result = await _client.rpc(
        'create_franchise_store',
        params: {
          'p_franchisor_store_id': franchisorStoreId,
          'p_owner_email': ownerEmail.trim().toLowerCase(),
          'p_store_name': storeName.trim(),
          'p_copy_stock': copyStock,
          'p_default_stock': defaultStock,
          'p_notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
          'p_primary_branch_name': 'Main',
        },
      );
      return FranchiseCreateResult.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not open franchise. Please try again.',
        cause: e,
      );
    }
  }

  Future<List<FranchiseStoreSummary>> listFranchiseStores(String franchisorStoreId) async {
    final result = await _client.rpc(
      'list_franchise_stores',
      params: {'p_franchisor_store_id': franchisorStoreId},
    );
    if (result is! List) return const [];
    return result
        .map((e) => FranchiseStoreSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Permanently deletes a franchise child store (Owner/Admin of franchisor only).
  Future<({String id, String name})> deleteFranchiseStore(String franchiseStoreId) async {
    final result = await _client.rpc(
      'delete_franchise_store',
      params: {'p_franchise_store_id': franchiseStoreId},
    );
    final map = Map<String, dynamic>.from(result as Map);
    return (
      id: map['id'] as String? ?? franchiseStoreId,
      name: map['name'] as String? ?? 'Franchise',
    );
  }

  Future<void> updateBusinessType({
    required String storeId,
    required BusinessType businessType,
  }) async {
    await _client.from('stores').update({
      'business_type': businessType.value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', storeId);
  }

  Future<void> updateStoreName({
    required String storeId,
    required String name,
  }) async {
    await _client.from('stores').update({
      'name': name.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', storeId);
  }

  Future<void> updatePaymentMethods({
    required String storeId,
    required bool acceptGcash,
    required bool acceptMaya,
    required bool acceptCard,
  }) async {
    await _client.from('stores').update({
      'accept_gcash': acceptGcash,
      'accept_maya': acceptMaya,
      'accept_card': acceptCard,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', storeId);
  }

  Future<void> updateReceiptFields({
    required String storeId,
    String? businessTin,
    String? businessAddress,
  }) async {
    await _client.from('stores').update({
      'business_tin': businessTin?.trim().isEmpty == true ? null : businessTin?.trim(),
      'business_address':
          businessAddress?.trim().isEmpty == true ? null : businessAddress?.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', storeId);
  }

  /// Soft cleanup + Edge Function hard delete (App Store requirement).
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('request_account_deletion');
    } catch (_) {
      // Edge Function still attempts admin delete.
    }
    final res = await _client.functions.invoke('delete-account');
    final data = res.data;
    if (data is Map && data['ok'] == true) return;
    final msg = data is Map
        ? (data['message'] as String? ?? data['error'] as String? ?? 'Delete failed')
        : 'Delete failed';
    throw AppException(msg);
  }

  Future<void> markOnboardingComplete() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('profiles').update({
      'onboarding_completed': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  Future<void> markTutorialComplete() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('profiles').update({
      'onboarding_completed': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  /// Uploads bytes to `product-images/{storeId}/{productId}/{ts}.ext` and returns public URL.
  Future<String> uploadProductImage({
    required String storeId,
    required String productId,
    required List<int> bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
    final path =
        '$storeId/$productId/${DateTime.now().toUtc().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('product-images').uploadBinary(
          path,
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    return _client.storage.from('product-images').getPublicUrl(path);
  }
}

