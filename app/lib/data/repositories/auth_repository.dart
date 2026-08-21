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
    try {
      await revenueCatBootstrapService.logOut();
    } catch (_) {}
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
        .select('id, store_id, role, branch_ids, stores(*)')
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
    List<String>? branchIds,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final map = await _createInvitationViaFunction(
            storeId: storeId,
            email: normalizedEmail,
            role: role,
            branchIds: branchIds,
          ) ??
          await _createInvitationViaRpc(
            storeId: storeId,
            email: normalizedEmail,
            role: role,
            branchIds: branchIds,
          );
      map['resent'] = map['resent'] == true;
      return map;
    } on AppException {
      rethrow;
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
      final blob = '${e.message} ${e.details} ${e.hint} ${e.code}';
      throw AppException(
        mapKnownBackendError(blob) ??
            mapKnownBackendError(e.toString()) ??
            'Could not send invite. Please try again.',
        cause: e,
      );
    }
  }

  Future<Map<String, dynamic>?> _createInvitationViaFunction({
    required String storeId,
    required String email,
    required StoreRole role,
    List<String>? branchIds,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'create-store-invitation',
        body: {
          'store_id': storeId,
          'email': email,
          'role': role.value,
          if (branchIds != null && branchIds.isNotEmpty)
            'branch_ids': branchIds,
        },
      );
      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['token'] != null) return map;
        final err = '${map['error'] ?? ''} ${map['code'] ?? ''} ${map['details'] ?? ''}';
        if (err.trim().isNotEmpty) {
          throw AppException(
            mapKnownBackendError(err) ??
                'Could not send invite. Please try again.',
          );
        }
      }
      return null;
    } on AppException {
      rethrow;
    } catch (e) {
      final blob = e.toString();
      if (blob.contains('404') || blob.toUpperCase().contains('NOT FOUND')) {
        return null;
      }
      final mapped = mapKnownBackendError(blob);
      if (mapped != null) throw AppException(mapped, cause: e);
      return null;
    }
  }

  Future<Map<String, dynamic>> _createInvitationViaRpc({
    required String storeId,
    required String email,
    required StoreRole role,
    List<String>? branchIds,
  }) async {
    final result = await _client.rpc(
      'create_store_invitation',
      params: {
        'p_store_id': storeId,
        'p_email': email,
        'p_role': role.value,
        if (branchIds != null && branchIds.isNotEmpty) 'p_branch_ids': branchIds,
      },
    );
    return Map<String, dynamic>.from(result as Map);
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
      return _inviteEmailResultFromPayload(res.data, fallbackUrl: inviteUrl);
    } catch (e) {
      // Non-2xx responses historically threw with a minified dump — parse details.
      final parsed = _inviteEmailResultFromException(e, fallbackUrl: inviteUrl);
      if (parsed != null) return parsed;
      return InviteEmailResult(
        emailed: false,
        reason: 'INVOKE_FAILED',
        inviteUrl: inviteUrl,
        message:
            'We couldn’t email them automatically. Copy the join link and send it yourself.',
      );
    }
  }

  static InviteEmailResult _inviteEmailResultFromPayload(
    Object? data, {
    String? fallbackUrl,
  }) {
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    final emailed = map['emailed'] == true;
    final reason = map['reason'] as String?;
    final rawMessage = map['message'] as String? ?? map['error'] as String?;
    return InviteEmailResult(
      emailed: emailed,
      inviteUrl: map['invite_url'] as String? ?? fallbackUrl,
      reason: reason,
      message: emailed
          ? null
          : _friendlyInviteEmailMessage(reason: reason, raw: rawMessage),
    );
  }

  static InviteEmailResult? _inviteEmailResultFromException(
    Object e, {
    String? fallbackUrl,
  }) {
    // FunctionException / invoke errors often embed `{details: {...}}` or JSON.
    final blob = e.toString();
    Map<String, dynamic>? map;

    // Prefer structured `details` when present on the exception object.
    try {
      final details = (e as dynamic).details;
      if (details is Map) {
        map = Map<String, dynamic>.from(details);
      } else if (details is String && details.trim().startsWith('{')) {
        // ignore — string form handled below
      }
    } catch (_) {}

    if (map == null) {
      final detailsMatch =
          RegExp(r'details:\s*(\{.*\})\s*,\s*reasonPhrase', dotAll: true)
              .firstMatch(blob);
      final jsonCandidate = detailsMatch?.group(1);
      if (jsonCandidate != null) {
        try {
          // details use JS-ish `{emailed: false}` — normalize keys for a light parse.
          final emailed = RegExp(r'emailed:\s*(true|false)')
                  .firstMatch(jsonCandidate)
                  ?.group(1) ==
              'true';
          final reason = RegExp(r'reason:\s*([A-Z0-9_]+)')
              .firstMatch(jsonCandidate)
              ?.group(1);
          final inviteUrl = RegExp(r'invite_url:\s*([^,}\s]+)')
              .firstMatch(jsonCandidate)
              ?.group(1);
          final message = RegExp(r'message:\s*([^}]*)\}\s*$')
              .firstMatch(jsonCandidate)
              ?.group(1)
              ?.trim();
          map = {
            'emailed': emailed,
            if (reason != null) 'reason': reason,
            if (inviteUrl != null) 'invite_url': inviteUrl,
            if (message != null && message.isNotEmpty) 'message': message,
          };
        } catch (_) {}
      }
    }

    if (map == null) return null;
    return _inviteEmailResultFromPayload(map, fallbackUrl: fallbackUrl);
  }

  static String _friendlyInviteEmailMessage({
    String? reason,
    String? raw,
  }) {
    const fallback =
        'We couldn’t email them automatically. Copy the join link and send it yourself.';
    final r = (reason ?? '').toUpperCase();
    if (r == 'NO_EMAIL_PROVIDER') {
      return 'Email sending isn’t configured yet. Copy the join link and send it yourself.';
    }
    if (r == 'RESEND_FAILED' || r == 'INVOKE_FAILED') {
      return fallback;
    }
    final cleaned = (raw ?? '').trim();
    if (cleaned.isEmpty) return fallback;
    // Never surface FunctionException / minified dumps in the invite UI.
    if (cleaned.contains('minified:') ||
        cleaned.contains('status: 502') ||
        cleaned.contains('FunctionException') ||
        cleaned.contains('details:')) {
      return fallback;
    }
    if (cleaned.length > 160) return fallback;
    return cleaned;
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

  Future<StoreSeatUsage> storeSeatUsage(String storeId) async {
    try {
      final result = await _client.rpc(
        'store_seat_usage',
        params: {'p_store_id': storeId},
      );
      // Returns SETOF — PostgREST may give a list of one row.
      if (result is List && result.isNotEmpty) {
        return StoreSeatUsage.fromJson(Map<String, dynamic>.from(result.first as Map));
      }
      if (result is Map) {
        return StoreSeatUsage.fromJson(Map<String, dynamic>.from(result));
      }
      return const StoreSeatUsage(activeMembers: 0, pendingInvites: 0, seatsUsed: 0);
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not load seat usage.',
        cause: e,
      );
    }
  }

  Future<void> updateMemberRole({
    required String memberId,
    required StoreRole role,
    List<String>? branchIds,
  }) async {
    try {
      await _client.rpc(
        'update_store_member_role',
        params: {
          'p_member_id': memberId,
          'p_role': role.value,
          if (branchIds != null) 'p_branch_ids': branchIds,
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

  Future<List<({String id, String name})>> listStoreBranches(String storeId) async {
    try {
      final result = await _client.rpc(
        'list_store_branches',
        params: {'p_store_id': storeId},
      );
      if (result is! List) return const [];
      return result.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return (id: m['id'] as String, name: m['name'] as String? ?? 'Branch');
      }).toList();
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ?? 'Could not load branches.',
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

  Future<void> setMyStorePin({
    required String storeId,
    required String pin,
  }) async {
    try {
      await _client.rpc(
        'set_my_store_pin',
        params: {
          'p_store_id': storeId,
          'p_pin': pin,
        },
      );
    } on PostgrestException catch (e) {
      throw AppException(
        friendlyError(e, fallback: 'Could not save PIN. Please try again.'),
        cause: e,
      );
    }
  }

  Future<void> adminClearMemberPin(String memberId) async {
    try {
      await _client.rpc(
        'admin_clear_member_pin',
        params: {'p_member_id': memberId},
      );
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not reset PIN. Please try again.',
        cause: e,
      );
    }
  }

  Future<bool> myStoreHasPin(String storeId) async {
    try {
      final result = await _client.rpc(
        'my_store_pin_status',
        params: {'p_store_id': storeId},
      );
      final map = Map<String, dynamic>.from(result as Map);
      return map['has_pin'] == true;
    } on PostgrestException catch (_) {
      return false;
    }
  }

  Future<void> verifyMemberPin({
    required String storeId,
    required String userId,
    required String pin,
  }) async {
    try {
      await _client.rpc(
        'verify_member_pin',
        params: {
          'p_store_id': storeId,
          'p_user_id': userId,
          'p_pin': pin,
        },
      );
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'PIN check failed. Please try again.',
        cause: e,
      );
    }
  }

  Future<List<ShiftRosterMember>> listShiftRoster(String storeId) async {
    try {
      final result = await _client.rpc(
        'list_shift_roster',
        params: {'p_store_id': storeId},
      );
      final map = Map<String, dynamic>.from(result as Map);
      final raw = map['members'];
      if (raw is! List) return const [];
      return raw
          .map((e) => ShiftRosterMember.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not load roster. Please try again.',
        cause: e,
      );
    }
  }

  Future<void> claimShiftWithPin({
    required String sessionId,
    required String userId,
    required String pin,
  }) async {
    try {
      await _client.rpc(
        'claim_shift_with_pin',
        params: {
          'p_session_id': sessionId,
          'p_user_id': userId,
          'p_pin': pin,
        },
      );
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not claim shift. Please try again.',
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
    final row = await _client
        .from('stores')
        .update({
          'name': name.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', storeId)
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw AppException(
        'Couldn’t update store name. Only Owner/Admin can change store settings.',
      );
    }
  }

  Future<void> updatePaymentMethods({
    required String storeId,
    required bool acceptGcash,
    required bool acceptMaya,
    required bool acceptCard,
  }) async {
    final row = await _client
        .from('stores')
        .update({
          'accept_gcash': acceptGcash,
          'accept_maya': acceptMaya,
          'accept_card': acceptCard,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', storeId)
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw AppException(
        'Couldn’t update payment methods. Only Owner/Admin can change store settings.',
      );
    }
  }

  Future<void> updateReceiptFields({
    required String storeId,
    String? businessTin,
    String? businessAddress,
  }) async {
    final tin = businessTin?.trim();
    final address = businessAddress?.trim();
    final row = await _client
        .from('stores')
        .update({
          'business_tin': (tin == null || tin.isEmpty) ? null : tin,
          'business_address': (address == null || address.isEmpty) ? null : address,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', storeId)
        .select('id, business_tin, business_address')
        .maybeSingle();
    if (row == null) {
      throw AppException(
        'Couldn’t save TIN/address. Only Owner/Admin can change receipt fields, '
        'or run Script B in Supabase if those columns are missing.',
      );
    }
  }

  /// Soft cleanup + Edge Function hard delete (App Store requirement).
  Future<void> deleteAccount() async {
    // Prefer the Edge Function (soft cleanup + auth.users hard delete).
    // RPC-only soft delete is insufficient for Apple 5.1.1(v).
    try {
      final res = await _client.functions.invoke('delete-account');
      final data = res.data;
      if (data is Map && data['ok'] == true) return;
      final msg = data is Map
          ? (data['message'] as String? ??
              data['error'] as String? ??
              'Delete failed')
          : 'Delete failed';
      throw AppException(msg);
    } on FunctionException catch (e) {
      final status = e.status;
      if (status == 404) {
        throw AppException(
          'Account deletion is temporarily unavailable. '
          'Please try again later or email support to delete your account.',
        );
      }
      final details = e.details;
      final msg = details is Map
          ? (details['message'] as String? ??
              details['error'] as String? ??
              e.reasonPhrase)
          : (e.reasonPhrase ?? 'Delete failed');
      throw AppException(msg ?? 'Delete failed');
    }
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

