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

/// Page offset for global recent transactions (10 per page).
final platformGlobalTxnOffsetProvider = StateProvider<int>((ref) => 0);

/// Page offset for a selected store's recent transactions (10 per page).
final platformStoreTxnOffsetProvider =
    StateProvider.family<int, String>((ref, storeId) => 0);

final platformTenantsProvider = FutureProvider<List<PlatformTenant>>((ref) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return const [];
  final q = ref.watch(platformTenantSearchProvider);
  return ref.watch(platformAdminRepositoryProvider).listTenants(search: q);
});

final platformUsageOverviewProvider = FutureProvider<PlatformUsageOverview?>((ref) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return null;
  return ref.watch(platformAdminRepositoryProvider).usageOverview();
});

final platformAnalyticsDaysProvider = StateProvider<int>((ref) => 30);

final platformAnalyticsProvider = FutureProvider<PlatformAnalyticsSeries?>((ref) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return null;
  final days = ref.watch(platformAnalyticsDaysProvider);
  return ref.watch(platformAdminRepositoryProvider).analyticsSeries(days: days);
});

final platformGlobalTransactionsProvider =
    FutureProvider<PlatformTransactionPage>((ref) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) {
    return const PlatformTransactionPage(
      transactions: [],
      totalCount: 0,
      limit: 10,
      offset: 0,
      hasMore: false,
    );
  }
  final offset = ref.watch(platformGlobalTxnOffsetProvider);
  return ref.watch(platformAdminRepositoryProvider).listRecentTransactions(
        offset: offset,
      );
});

final platformStoreTransactionsProvider =
    FutureProvider.family<PlatformTransactionPage, String>((ref, storeId) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) {
    return const PlatformTransactionPage(
      transactions: [],
      totalCount: 0,
      limit: 10,
      offset: 0,
      hasMore: false,
    );
  }
  final offset = ref.watch(platformStoreTxnOffsetProvider(storeId));
  return ref.watch(platformAdminRepositoryProvider).listRecentTransactions(
        storeId: storeId,
        offset: offset,
      );
});

final platformStoreSetupProvider =
    FutureProvider.family<PlatformStoreSetup?, String>((ref, storeId) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return null;
  return ref.watch(platformAdminRepositoryProvider).getStoreSetup(storeId);
});

final platformSupportNotesProvider =
    FutureProvider.family<List<PlatformSupportNote>, String>((ref, storeId) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(platformAdminRepositoryProvider).listSupportNotes(storeId);
});

final platformStoreMessagesAdminProvider =
    FutureProvider.family<List<PlatformStoreMessage>, String>((ref, storeId) async {
  final isAdmin = await ref.watch(isPlatformAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(platformAdminRepositoryProvider).listStoreMessagesAdmin(storeId);
});

final myStoreMessagesProvider =
    FutureProvider.family<List<PlatformStoreMessage>, String>((ref, storeId) async {
  ref.watch(authUserIdProvider);
  return ref.watch(platformAdminRepositoryProvider).listMyStoreMessages(storeId);
});
