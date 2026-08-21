import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// Retries a few times — RevenueCat entitlement can lag behind StoreKit.
Future<void> syncPremiumEntitlementToStore({
  required String storeId,
}) async {
  final client = supabaseOrNull;
  if (client == null) {
    throw StateError('Not connected to the server.');
  }

  Object? lastError;
  for (var attempt = 0; attempt < 4; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
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
    } on FunctionException catch (e) {
      final details = e.details;
      lastError = details is Map
          ? (details['message'] as String? ??
              details['error'] as String? ??
              e.reasonPhrase)
          : (e.reasonPhrase ?? 'Sync failed');
    } catch (e) {
      lastError = e;
    }
  }
  throw StateError(lastError?.toString() ?? 'Sync failed');
}
