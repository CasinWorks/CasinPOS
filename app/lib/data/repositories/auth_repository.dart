import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_models.dart';
import '../../domain/enums.dart';
import '../../bootstrap.dart';

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

  Future<void> signOut() => _client.auth.signOut();
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

  Future<Map<String, dynamic>> createInvitation({
    required String storeId,
    required String email,
    required StoreRole role,
  }) async {
    final result = await _client.rpc(
      'create_store_invitation',
      params: {
        'p_store_id': storeId,
        'p_email': email.trim().toLowerCase(),
        'p_role': role.value,
        'p_branch_ids': null,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<String> acceptInvitation(String token) async {
    final result = await _client.rpc(
      'accept_store_invitation',
      params: {'p_token': token.trim()},
    );
    return result as String;
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

