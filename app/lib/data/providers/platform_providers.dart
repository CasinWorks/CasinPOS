import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/platform_models.dart';
import '../repositories/platform_admin_repository.dart';
import 'session_providers.dart';

final platformAdminRepositoryProvider = Provider<PlatformAdminRepository>(
  (ref) => PlatformAdminRepository(),
);

/// True when signed-in user has profiles.is_platform_admin.
final isPlatformAdminProvider = FutureProvider<bool>((ref) async {
  ref.watch(authUserIdProvider);
  if (ref.watch(authUserIdProvider) == null) return false;
  return ref.watch(platformAdminRepositoryProvider).amIPlatformAdmin();
});

final platformTenantSearchProvider = StateProvider<String>((ref) => '');

final platformTenantsProvider = FutureProvider<List<PlatformTenant>>((ref) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return const [];
  final q = ref.watch(platformTenantSearchProvider);
  return ref.watch(platformAdminRepositoryProvider).listTenants(search: q);
});
