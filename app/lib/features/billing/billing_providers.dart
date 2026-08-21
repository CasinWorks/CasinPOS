import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../bootstrap.dart';
import '../../data/providers/session_providers.dart';
import 'revenuecat_service.dart';

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return revenueCatBootstrapService;
});

/// Configures RevenueCat once and keeps App User ID in sync with Supabase auth.
final revenueCatBootstrapProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(revenueCatServiceProvider);
  await service.configure();

  final userId = ref.watch(authUserIdProvider);
  if (userId != null) {
    await service.logIn(userId);
    final storeId = ref.read(activeMembershipProvider)?.storeId;
    if (storeId != null) await service.setStoreId(storeId);
  } else {
    await service.logOut();
  }
});

final premiumMonthlyPackageProvider = FutureProvider<Package?>((ref) async {
  await ref.watch(revenueCatBootstrapProvider.future);
  return ref.watch(revenueCatServiceProvider).monthlyPremiumPackage();
});

/// Asks Supabase to apply Premium after a successful Store purchase/restore.
Future<void> syncPremiumEntitlementToStore({
  required String storeId,
}) async {
  final client = supabaseOrNull;
  if (client == null) return;
  final res = await client.functions.invoke(
    'sync-my-premium',
    body: {'store_id': storeId},
  );
  final data = res.data;
  if (data is Map && data['ok'] == true) return;
  final msg = data is Map
      ? (data['message'] as String? ?? data['error'] as String? ?? 'Sync failed')
      : 'Sync failed';
  throw StateError(msg);
}
