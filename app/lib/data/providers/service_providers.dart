import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/permissions.dart';
import '../models/service_models.dart';
import '../repositories/service_repository.dart';
import 'pos_providers.dart';
import 'report_providers.dart';
import 'session_providers.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository();
});

final serviceCatalogProvider = FutureProvider<List<ServiceOffering>>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null) return const [];
  return ref.watch(serviceRepositoryProvider).listServices(membership.storeId);
});

final serviceQuotesProvider = FutureProvider<List<ServiceQuote>>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null) return const [];
  return ref.watch(serviceRepositoryProvider).listQuotes(membership.storeId);
});

final serviceBookingsProvider = FutureProvider<List<ServiceBooking>>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null) return const [];
  return ref.watch(serviceRepositoryProvider).listBookings(membership.storeId);
});

final serviceReportStatsProvider = FutureProvider<ServiceReportStats?>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null || !Permissions.canViewReports(membership.role)) {
    return null;
  }
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(serviceRepositoryProvider).reportStats(
        storeId: membership.storeId,
        start: range.start,
        end: range.end,
        branchId: ref.watch(effectiveReportBranchIdProvider),
      );
});

/// Reload sales history + report caches after a service booking or payment.
Future<void> refreshServiceSales(WidgetRef ref) async {
  final storeId = ref.read(activeMembershipProvider)?.storeId;
  if (storeId != null) {
    await ref.read(ordersProvider.notifier).loadForStore(storeId);
  }
  ref.invalidate(serviceBookingsProvider);
  ref.invalidate(serviceQuotesProvider);
  ref.invalidate(serviceReportStatsProvider);
  ref.invalidate(serviceCustomersProvider);
  ref.invalidate(reportDashboardProvider);
  ref.invalidate(salesLineReportProvider);
}

final serviceCustomersProvider = FutureProvider<List<ServiceCustomer>>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null) return const [];
  return ref.watch(serviceRepositoryProvider).listCustomers(membership.storeId);
});
