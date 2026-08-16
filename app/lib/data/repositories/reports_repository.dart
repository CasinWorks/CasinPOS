import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_errors.dart';
import '../models/report_models.dart';

class ReportsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<StoreBranch>> listBranches(String storeId) async {
    try {
      final result = await _client.rpc(
        'list_store_branches',
        params: {'p_store_id': storeId},
      );
      if (result is! List) return const [];
      return result
          .whereType<Map>()
          .map((e) => StoreBranch.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ?? 'Could not load branches.',
        cause: e,
      );
    }
  }

  Future<List<InventoryReportRow>> inventoryReport({
    required String storeId,
    String? branchId,
    bool lowStockOnly = false,
  }) async {
    final result = await _rpc('report_inventory', {
      'p_store_id': storeId,
      'p_branch_id': branchId,
      'p_low_stock_only': lowStockOnly,
    });
    return _rows(result).map(InventoryReportRow.fromJson).toList();
  }

  Future<List<SalesLineReportRow>> salesLineReport({
    required String storeId,
    required DateTime start,
    required DateTime end,
    String? branchId,
  }) async {
    final result = await _rpc('report_sales_lines', {
      'p_store_id': storeId,
      'p_start': start.toUtc().toIso8601String(),
      'p_end': end.toUtc().toIso8601String(),
      'p_branch_id': branchId,
    });
    return _rows(result).map(SalesLineReportRow.fromJson).toList();
  }

  Future<List<ProfitabilityReportRow>> profitabilityReport({
    required String storeId,
    required DateTime start,
    required DateTime end,
    String? branchId,
  }) async {
    final result = await _rpc('report_profitability', {
      'p_store_id': storeId,
      'p_start': start.toUtc().toIso8601String(),
      'p_end': end.toUtc().toIso8601String(),
      'p_branch_id': branchId,
    });
    return _rows(result).map(ProfitabilityReportRow.fromJson).toList();
  }

  Future<ReportDashboardStats> dashboardStats({
    required String storeId,
    required DateTime start,
    required DateTime end,
    String? branchId,
    int deadStockDays = 30,
  }) async {
    final result = await _rpc('report_dashboard_stats', {
      'p_store_id': storeId,
      'p_start': start.toUtc().toIso8601String(),
      'p_end': end.toUtc().toIso8601String(),
      'p_branch_id': branchId,
      'p_dead_stock_days': deadStockDays,
    });
    return ReportDashboardStats.fromJson(result);
  }

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await _client.rpc(name, params: params);
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not load report.',
        cause: e,
      );
    }
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> result) {
    final raw = result['rows'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
