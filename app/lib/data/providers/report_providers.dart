import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/permissions.dart';
import '../models/report_models.dart';
import '../repositories/reports_repository.dart';
import 'session_providers.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository();
});

final storeBranchesProvider = FutureProvider<List<StoreBranch>>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null) return const [];
  return ref.watch(reportsRepositoryProvider).listBranches(membership.storeId);
});

/// null = all accessible branches (owners/admins/managers only).
final reportBranchScopeProvider = StateProvider<String?>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null) return null;
  if (membership.role.isBranchScoped) {
    return membership.branchIds.isNotEmpty ? membership.branchIds.first : null;
  }
  return null;
});

/// Effective branch id sent to RPCs (null = merged/all accessible).
final effectiveReportBranchIdProvider = Provider<String?>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null) return null;
  if (membership.role.isBranchScoped) {
    final locked = ref.watch(reportBranchScopeProvider);
    if (locked != null) return locked;
    return membership.branchIds.isNotEmpty ? membership.branchIds.first : null;
  }
  if (!membership.role.canSelectBranchScope) return null;
  return ref.watch(reportBranchScopeProvider);
});

final reportDateRangeProvider =
    StateProvider<({DateTime start, DateTime end})>((ref) {
  final end = DateTime.now();
  final start = DateTime(end.year, end.month, end.day)
      .subtract(const Duration(days: 6));
  return (start: start, end: end.add(const Duration(days: 1)));
});

final canViewReportsProvider = Provider<bool>((ref) {
  final role = ref.watch(activeMembershipProvider)?.role;
  if (role == null) return false;
  return Permissions.canViewReports(role);
});

final includeBranchColumnInExportProvider = Provider<bool>((ref) {
  return ref.watch(effectiveReportBranchIdProvider) == null;
});

final inventoryReportProvider =
    FutureProvider.family<List<InventoryReportRow>, bool>((ref, lowOnly) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null || !Permissions.canViewReports(membership.role)) {
    return const [];
  }
  return ref.watch(reportsRepositoryProvider).inventoryReport(
        storeId: membership.storeId,
        branchId: ref.watch(effectiveReportBranchIdProvider),
        lowStockOnly: lowOnly,
      );
});

final salesLineReportProvider =
    FutureProvider<List<SalesLineReportRow>>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null || !Permissions.canViewReports(membership.role)) {
    return const [];
  }
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(reportsRepositoryProvider).salesLineReport(
        storeId: membership.storeId,
        start: range.start,
        end: range.end,
        branchId: ref.watch(effectiveReportBranchIdProvider),
      );
});

final profitabilityReportProvider =
    FutureProvider<List<ProfitabilityReportRow>>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null || !Permissions.canViewReports(membership.role)) {
    return const [];
  }
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(reportsRepositoryProvider).profitabilityReport(
        storeId: membership.storeId,
        start: range.start,
        end: range.end,
        branchId: ref.watch(effectiveReportBranchIdProvider),
      );
});

final reportDashboardProvider = FutureProvider<ReportDashboardStats?>((ref) async {
  final membership = ref.watch(activeMembershipProvider);
  if (membership == null || !Permissions.canViewReports(membership.role)) {
    return null;
  }
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(reportsRepositoryProvider).dashboardStats(
        storeId: membership.storeId,
        start: range.start,
        end: range.end,
        branchId: ref.watch(effectiveReportBranchIdProvider),
      );
});
