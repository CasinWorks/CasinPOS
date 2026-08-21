import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap.dart';
import '../../data/providers/session_providers.dart';
import '../../domain/enums.dart';
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

/// When an Owner opens a Free store and this Apple/Google account already has
/// Premium, attach + sync automatically (no extra Restore tap).
final premiumAutoSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  await ref.watch(revenueCatBootstrapProvider.future);
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null) return;
  if (membership.role != StoreRole.owner) return;
  if (membership.store.planTier == PlanTier.premium) return;

  final service = ref.read(revenueCatServiceProvider);
  if (!service.isConfigured) return;

  final storeId = membership.storeId;
  final entitled =
      await service.attachStorePurchasesToCurrentUser(storeId: storeId);
  if (!entitled) return;

  try {
    await syncPremiumEntitlementToStore(storeId: storeId);
    ref.invalidate(membershipsProvider);
  } catch (_) {
    // Bound to another store or RC lag — Upgrade sheet will show the reason.
  }
});

/// Asks Supabase to apply Premium after a successful Store purchase/restore.
/// Retries a few times — RevenueCat entitlement can lag behind StoreKit.
Future<void> syncPremiumEntitlementToStore({
  required String storeId,
}) async {
  final client = supabaseOrNull;
  if (client == null) {
    throw StateError('Not connected to the server.');
  }

  Object? lastError;
  for (var attempt = 0; attempt < 5; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
    }
    try {
      final res = await client.functions.invoke(
        'sync-my-premium',
        body: {'store_id': storeId},
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) return;
      lastError = data is Map
          ? (data['message'] as String? ??
              data['error'] as String? ??
              'Sync failed')
          : 'Sync failed';
      if (data is Map &&
          data['error'] == 'SUBSCRIPTION_BOUND_TO_OTHER_STORE') {
        throw StateError(lastError.toString());
      }
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map
          ? (details['message'] as String? ??
              details['error'] as String? ??
              e.reasonPhrase)
          : (e.reasonPhrase ?? 'Sync failed');
      lastError = message;
      if (details is Map &&
          details['error'] == 'SUBSCRIPTION_BOUND_TO_OTHER_STORE') {
        throw StateError(message ?? 'Subscription bound to another store');
      }
      if (e.status == 409) {
        throw StateError(message ?? 'Subscription bound to another store');
      }
    } catch (e) {
      if (e is StateError) rethrow;
      lastError = e;
    }
  }
  throw StateError(lastError?.toString() ?? 'Sync failed');
}
