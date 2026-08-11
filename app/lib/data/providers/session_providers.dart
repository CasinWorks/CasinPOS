import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../models/store_models.dart';
import '../../bootstrap.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final storeRepositoryProvider = Provider<StoreRepository>((ref) => StoreRepository());

/// Emits on every auth change. null session = signed out.
final authStateProvider = StreamProvider<AuthState>((ref) {
  if (!isSupabaseReady) {
    return const Stream.empty();
  }
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  if (!isSupabaseReady) return null;
  return ref.watch(authRepositoryProvider).currentSession;
});

/// Stable auth identity. Re-auth / token refresh keeps the same id, so
/// dependents (memberships, shell) do not rebuild under open dialogs.
final authUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  if (!isSupabaseReady) return null;
  return ref.watch(authRepositoryProvider).currentSession?.user.id;
});

final membershipsProvider = FutureProvider<List<StoreMembership>>((ref) async {
  // Only re-fetch when the signed-in user changes — not on every auth tick
  // (password re-confirm via signInWithPassword must not wipe the shell).
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return [];
  return ref.watch(storeRepositoryProvider).fetchMemberships();
});

const _kActiveStorePrefPrefix = 'casinpos.active_store_id.';

/// In-memory preferred store id for the signed-in user (persisted to prefs).
final preferredStoreIdProvider =
    StateNotifierProvider<PreferredStoreIdController, String?>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final controller = PreferredStoreIdController(userId: userId);
  if (userId != null) {
    controller.load();
  }
  return controller;
});

class PreferredStoreIdController extends StateNotifier<String?> {
  PreferredStoreIdController({required this.userId}) : super(null);

  final String? userId;

  Future<void> load() async {
    final uid = userId;
    if (uid == null) {
      state = null;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('$_kActiveStorePrefPrefix$uid');
    if (!mounted) return;
    state = saved;
  }

  Future<void> select(String storeId) async {
    state = storeId;
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kActiveStorePrefPrefix$uid', storeId);
  }
}

/// Selected active membership (persisted store switcher when multi-store).
final activeMembershipProvider = Provider<StoreMembership?>((ref) {
  final memberships = ref.watch(membershipsProvider).valueOrNull;
  if (memberships == null || memberships.isEmpty) return null;
  final preferred = ref.watch(preferredStoreIdProvider);
  if (preferred != null) {
    for (final m in memberships) {
      if (m.storeId == preferred) return m;
    }
  }
  return memberships.first;
});

final introSeenProvider = StateProvider<bool>((ref) => false);

/// Set when Supabase fires [AuthChangeEvent.passwordRecovery].
final passwordRecoveryPendingProvider = StateProvider<bool>((ref) => false);
