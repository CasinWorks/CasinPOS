import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Selected active membership (first for now; branch switcher later).
final activeMembershipProvider = Provider<StoreMembership?>((ref) {
  final memberships = ref.watch(membershipsProvider).valueOrNull;
  if (memberships == null || memberships.isEmpty) return null;
  return memberships.first;
});

final introSeenProvider = StateProvider<bool>((ref) => false);
