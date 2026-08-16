import 'package:intl/intl.dart';

class StoreBranch {
  const StoreBranch({
    required this.id,
    required this.name,
    this.address,
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String? address;
  final bool isPrimary;

  factory StoreBranch.fromJson(Map<String, dynamic> json) => StoreBranch(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Branch',
        address: json['address'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
      );
}

class InventoryReportRow {
  const InventoryReportRow({
    required this.sku,
    required this.itemName,
    required this.category,
    required this.branchName,
    required this.currentStock,
    required this.unitCost,
    required this.stockValue,
    required this.reorderThreshold,
    required this.lowStockFlag,
    this.lastRestockedDate,
    this.supplier,
  });

  final String sku;
  final String itemName;
  final String category;
  final String branchName;
  final double currentStock;
  final double unitCost;
  final double stockValue;
  final double reorderThreshold;
  final bool lowStockFlag;
  final DateTime? lastRestockedDate;
  final String? supplier;

  factory InventoryReportRow.fromJson(Map<String, dynamic> json) =>
      InventoryReportRow(
        sku: json['sku'] as String? ?? '',
        itemName: json['item_name'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        branchName: json['branch_name'] as String? ?? '',
        currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0,
        unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
        stockValue: (json['stock_value'] as num?)?.toDouble() ?? 0,
        reorderThreshold: (json['reorder_threshold'] as num?)?.toDouble() ?? 0,
        lowStockFlag: json['low_stock_flag'] as bool? ?? false,
        lastRestockedDate:
            DateTime.tryParse(json['last_restocked_date'] as String? ?? ''),
        supplier: json['supplier'] as String?,
      );
}

class SalesLineReportRow {
  const SalesLineReportRow({
    required this.transactionId,
    required this.date,
    required this.time,
    required this.branchName,
    required this.itemName,
    required this.category,
    required this.qty,
    required this.unitPrice,
    required this.discount,
    required this.tax,
    required this.lineTotal,
    required this.paymentMethod,
    required this.staffName,
    required this.orderType,
  });

  final String transactionId;
  final DateTime date;
  final String time;
  final String branchName;
  final String itemName;
  final String category;
  final double qty;
  final double unitPrice;
  final double discount;
  final double tax;
  final double lineTotal;
  final String paymentMethod;
  final String staffName;
  final String orderType;

  factory SalesLineReportRow.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'];
    DateTime date;
    if (dateRaw is String) {
      date = DateTime.tryParse(dateRaw) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }
    return SalesLineReportRow(
      transactionId: json['transaction_id'] as String? ?? '',
      date: date,
      time: json['time'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? '',
      staffName: json['staff_name'] as String? ?? 'Staff',
      orderType: json['order_type'] as String? ?? 'retail',
    );
  }
}

class ProfitabilityReportRow {
  const ProfitabilityReportRow({
    required this.itemName,
    required this.category,
    required this.branchName,
    required this.unitsSold,
    required this.revenue,
    required this.cogsTotal,
    required this.grossProfit,
    required this.marginPct,
    required this.rank,
  });

  final String itemName;
  final String category;
  final String branchName;
  final double unitsSold;
  final double revenue;
  final double cogsTotal;
  final double grossProfit;
  final double marginPct;
  final int rank;

  factory ProfitabilityReportRow.fromJson(Map<String, dynamic> json) =>
      ProfitabilityReportRow(
        itemName: json['item_name'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        branchName: json['branch_name'] as String? ?? '',
        unitsSold: (json['units_sold'] as num?)?.toDouble() ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
        cogsTotal: (json['cogs_total'] as num?)?.toDouble() ?? 0,
        grossProfit: (json['gross_profit'] as num?)?.toDouble() ?? 0,
        marginPct: (json['margin_pct'] as num?)?.toDouble() ?? 0,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
      );
}

class BranchBreakdownRow {
  const BranchBreakdownRow({
    required this.branchId,
    required this.branchName,
    required this.revenue,
    required this.unitsSold,
    required this.transactions,
  });

  final String branchId;
  final String branchName;
  final double revenue;
  final double unitsSold;
  final int transactions;

  factory BranchBreakdownRow.fromJson(Map<String, dynamic> json) =>
      BranchBreakdownRow(
        branchId: json['branch_id'] as String? ?? '',
        branchName: json['branch_name'] as String? ?? '',
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
        unitsSold: (json['units_sold'] as num?)?.toDouble() ?? 0,
        transactions: (json['transactions'] as num?)?.toInt() ?? 0,
      );
}

class DayTrendPoint {
  const DayTrendPoint({
    required this.day,
    required this.revenue,
    required this.unitsSold,
  });

  final DateTime day;
  final double revenue;
  final double unitsSold;

  factory DayTrendPoint.fromJson(Map<String, dynamic> json) {
    final raw = json['day'];
    return DayTrendPoint(
      day: raw is String
          ? (DateTime.tryParse(raw) ?? DateTime.now())
          : DateTime.now(),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      unitsSold: (json['units_sold'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TopProductStat {
  const TopProductStat({
    required this.itemName,
    required this.unitsSold,
    required this.revenue,
  });

  final String itemName;
  final double unitsSold;
  final double revenue;

  factory TopProductStat.fromJson(Map<String, dynamic> json) => TopProductStat(
        itemName: json['item_name'] as String? ?? '',
        unitsSold: (json['units_sold'] as num?)?.toDouble() ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

class ReportDashboardStats {
  const ReportDashboardStats({
    required this.revenue,
    required this.unitsSold,
    required this.transactions,
    required this.prevRevenue,
    required this.prevUnits,
    this.revenueChangePct,
    this.unitsChangePct,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.deadStockCount,
    required this.topProducts,
    required this.byBranch,
    required this.byDay,
  });

  final double revenue;
  final double unitsSold;
  final int transactions;
  final double prevRevenue;
  final double prevUnits;
  final double? revenueChangePct;
  final double? unitsChangePct;
  final double inventoryValue;
  final int lowStockCount;
  final int deadStockCount;
  final List<TopProductStat> topProducts;
  final List<BranchBreakdownRow> byBranch;
  final List<DayTrendPoint> byDay;

  factory ReportDashboardStats.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> listOf(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return ReportDashboardStats(
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      unitsSold: (json['units_sold'] as num?)?.toDouble() ?? 0,
      transactions: (json['transactions'] as num?)?.toInt() ?? 0,
      prevRevenue: (json['prev_revenue'] as num?)?.toDouble() ?? 0,
      prevUnits: (json['prev_units'] as num?)?.toDouble() ?? 0,
      revenueChangePct: (json['revenue_change_pct'] as num?)?.toDouble(),
      unitsChangePct: (json['units_change_pct'] as num?)?.toDouble(),
      inventoryValue: (json['inventory_value'] as num?)?.toDouble() ?? 0,
      lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
      deadStockCount: (json['dead_stock_count'] as num?)?.toInt() ?? 0,
      topProducts: listOf('top_products').map(TopProductStat.fromJson).toList(),
      byBranch: listOf('by_branch').map(BranchBreakdownRow.fromJson).toList(),
      byDay: listOf('by_day').map(DayTrendPoint.fromJson).toList(),
    );
  }
}

/// Shared CSV helpers for CasinPOS reports.
abstract final class ReportCsv {
  static final decimal = NumberFormat('0.##');
  static final money = NumberFormat('0.00');
  static final day = DateFormat('yyyy-MM-dd');

  static String escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String row(List<String> cells) => cells.map(escape).join(',');

  static String filename({
    required String report,
    required String branchOrAll,
    required DateTime start,
    required DateTime end,
  }) {
    final safeBranch = branchOrAll
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'casinpos_${report}_${safeBranch.isEmpty ? 'all' : safeBranch}_'
        '${day.format(start)}_${day.format(end)}.csv';
  }

  static String inventory({
    required List<InventoryReportRow> rows,
    required bool includeBranch,
  }) {
    final headers = <String>[
      'sku',
      'item_name',
      'category',
      if (includeBranch) 'branch_name',
      'current_stock',
      'unit_cost',
      'stock_value',
      'reorder_threshold',
      'low_stock_flag',
      'last_restocked_date',
      'supplier',
    ];
    final buf = StringBuffer()..writeln(row(headers));
    for (final r in rows) {
      buf.writeln(row([
        r.sku,
        r.itemName,
        r.category,
        if (includeBranch) r.branchName,
        decimal.format(r.currentStock),
        money.format(r.unitCost),
        money.format(r.stockValue),
        decimal.format(r.reorderThreshold),
        r.lowStockFlag ? 'true' : 'false',
        r.lastRestockedDate == null ? '' : day.format(r.lastRestockedDate!),
        r.supplier ?? '',
      ]));
    }
    return buf.toString();
  }

  static String salesLines({
    required List<SalesLineReportRow> rows,
    required bool includeBranch,
  }) {
    final headers = <String>[
      'transaction_id',
      'date',
      'time',
      if (includeBranch) 'branch_name',
      'item_name',
      'category',
      'qty',
      'unit_price',
      'discount',
      'tax',
      'line_total',
      'payment_method',
      'staff_name',
      'order_type',
    ];
    final buf = StringBuffer()..writeln(row(headers));
    for (final r in rows) {
      buf.writeln(row([
        r.transactionId,
        day.format(r.date),
        r.time,
        if (includeBranch) r.branchName,
        r.itemName,
        r.category,
        decimal.format(r.qty),
        money.format(r.unitPrice),
        money.format(r.discount),
        money.format(r.tax),
        money.format(r.lineTotal),
        r.paymentMethod,
        r.staffName,
        r.orderType,
      ]));
    }
    return buf.toString();
  }

  static String profitability({
    required List<ProfitabilityReportRow> rows,
    required bool includeBranch,
  }) {
    final headers = <String>[
      'rank',
      'item_name',
      'category',
      if (includeBranch) 'branch_name',
      'units_sold',
      'revenue',
      'cogs_total',
      'gross_profit',
      'margin_pct',
    ];
    final buf = StringBuffer()..writeln(row(headers));
    for (final r in rows) {
      buf.writeln(row([
        '${r.rank}',
        r.itemName,
        r.category,
        if (includeBranch) r.branchName,
        decimal.format(r.unitsSold),
        money.format(r.revenue),
        money.format(r.cogsTotal),
        money.format(r.grossProfit),
        money.format(r.marginPct),
      ]));
    }
    return buf.toString();
  }
}
