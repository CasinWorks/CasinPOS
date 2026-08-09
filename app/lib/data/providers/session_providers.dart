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

final membershipsProvider = FutureProvider<List<StoreMembership>>((ref) async {
  // Re-fetch whenever auth stream ticks.
  ref.watch(authStateProvider);
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  return ref.watch(storeRepositoryProvider).fetchMemberships();
});

/// Selected active membership (first for now; branch switcher later).
final activeMembershipProvider = Provider<StoreMembership?>((ref) {
  final memberships = ref.watch(membershipsProvider).valueOrNull;
  if (memberships == null || memberships.isEmpty) return null;
  return memberships.first;
});

final introSeenProvider = StateProvider<bool>((ref) => false);
