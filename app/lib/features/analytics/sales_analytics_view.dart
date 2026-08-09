import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../onboarding/tutorial_anchors.dart';
import 'sales_report_pdf.dart';

class SalesAnalyticsView extends ConsumerStatefulWidget {
  const SalesAnalyticsView({super.key});

  @override
  ConsumerState<SalesAnalyticsView> createState() => _SalesAnalyticsViewState();
}

class _SalesAnalyticsViewState extends ConsumerState<SalesAnalyticsView> {
  String _period = 'today';

  DateTime _periodStart(String period, DateTime now) {
    switch (period) {
      case 'week':
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case 'month':
        return DateTime(now.year, now.month);
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _previousPeriodStart(String period, DateTime start) {
    switch (period) {
      case 'week':
        return start.subtract(const Duration(days: 7));
      case 'month':
        return DateTime(start.year, start.month - 1);
      default:
        return start.subtract(const Duration(days: 1));
    }
  }

  List<PosOrder> _inRange(List<PosOrder> all, DateTime start, DateTime end) {
    return all
        .where((o) => !o.createdAt.isBefore(start) && o.createdAt.isBefore(end))
        .toList();
  }

  Future<void> _exportPdf({
    required List<PosOrder> orders,
    required DateTime start,
    required DateTime end,
  }) async {
    final store = ref.read(activeMembershipProvider)?.store;
    final periodLabel = switch (_period) {
      'week' => 'This week',
      'month' => 'This month',
      _ => 'Today',
    };
    final rangeLabel =
        '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end.subtract(const Duration(minutes: 1)))}';
    final data = SalesReportData(
      storeName: store?.name ?? 'CasinPOS Store',
      currencySymbol: store?.currencySymbol ?? '₱',
      periodLabel: periodLabel,
      rangeLabel: rangeLabel,
      orders: orders,
    );
    final doc = await buildSalesReportPdf(data);
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  List<FlSpot> _revenueSpots(List<PosOrder> orders, String period) {
    if (orders.isEmpty) return [const FlSpot(0, 0)];

    if (period == 'today') {
      final byHour = List<double>.filled(24, 0);
      for (final o in orders) {
        byHour[o.createdAt.hour] += o.total;
      }
      // Show open hours with activity, or all 24 if sparse
      final spots = <FlSpot>[];
      for (var h = 0; h < 24; h++) {
        if (byHour[h] > 0 || (h >= 8 && h <= 22)) {
          spots.add(FlSpot(h.toDouble(), byHour[h]));
        }
      }
      return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
    }

    if (period == 'week') {
      final byDow = List<double>.filled(7, 0);
      for (final o in orders) {
        byDow[o.createdAt.weekday - 1] += o.total;
      }
      return [
        for (var i = 0; i < 7; i++) FlSpot(i.toDouble(), byDow[i]),
      ];
    }

    // month — by day of month
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final byDay = List<double>.filled(daysInMonth, 0);
    for (final o in orders) {
      final d = o.createdAt.day - 1;
      if (d >= 0 && d < daysInMonth) byDay[d] += o.total;
    }
    return [
      for (var i = 0; i < daysInMonth; i++) FlSpot((i + 1).toDouble(), byDay[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(paidOrdersProvider);
    final symbol = ref.watch(activeMembershipProvider)?.store.currencySymbol ?? '₱';
    final now = DateTime.now();
    final start = _periodStart(_period, now);
    final end = _period == 'month'
        ? DateTime(start.year, start.month + 1)
        : _period == 'week'
            ? start.add(const Duration(days: 7))
            : start.add(const Duration(days: 1));
    final prevStart = _previousPeriodStart(_period, start);

    final orders = _inRange(allOrders, start, end);
    final prevOrders = _inRange(allOrders, prevStart, start);

    final revenue = orders.fold<double>(0, (s, o) => s + o.total);
    final prevRevenue = prevOrders.fold<double>(0, (s, o) => s + o.total);
    final packs = orders.fold<int>(0, (s, o) => s + o.items.fold<int>(0, (a, i) => a + i.qty));
    final avgBasket = orders.isEmpty ? 0.0 : revenue / orders.length;

    String trendLabel;
    Color? trendColor;
    if (prevRevenue <= 0 && revenue <= 0) {
      trendLabel = 'No prior period data';
      trendColor = AppColors.slate400;
    } else if (prevRevenue <= 0) {
      trendLabel = 'New sales this period';
      trendColor = AppColors.success;
    } else {
      final pct = ((revenue - prevRevenue) / prevRevenue) * 100;
      final sign = pct >= 0 ? '+' : '';
      trendLabel = '$sign${pct.toStringAsFixed(1)}% vs previous $_period';
      trendColor = pct >= 0 ? AppColors.success : AppColors.danger;
    }

    final byProduct = <String, int>{};
    final byCategory = <String, double>{};
    for (final o in orders) {
      for (final i in o.items) {
        byProduct[i.name] = (byProduct[i.name] ?? 0) + i.qty;
        byCategory[i.category] = (byCategory[i.category] ?? 0) + i.unitPrice * i.qty;
      }
    }
    final best = byProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCat = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final byPay = <PaymentMethod, double>{};
    for (final o in orders) {
      byPay[o.paymentMethod] = (byPay[o.paymentMethod] ?? 0) + o.total;
    }

    final spots = _revenueSpots(orders, _period);
    final maxY = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = maxY <= 0 ? 1.0 : maxY * 1.2;

    final periodTitle = switch (_period) {
      'week' => 'WEEK',
      'month' => 'MONTH',
      _ => 'DAY',
    };

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sales Analytics & Best Sellers',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: 'Export owner report PDF',
                  onPressed: () => _exportPdf(orders: orders, start: start, end: end),
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
                ),
                TutorialTarget(
                  anchor: TutorialAnchor.analyticsPeriod,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final p in ['today', 'week', 'month']) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(
                              p == 'today'
                                  ? 'Daily Today'
                                  : p == 'week'
                                      ? 'This Week'
                                      : 'This Month',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _period == p ? AppColors.slate900 : Colors.white70,
                              ),
                            ),
                            selected: _period == p,
                            selectedColor: AppColors.retail,
                            backgroundColor: const Color(0xFF1E293B),
                            onSelected: (_) => setState(() => _period = p),
                            showCheckmark: false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  title: 'Total Revenue',
                  value: '$symbol${revenue.toStringAsFixed(2)}',
                  sub: trendLabel,
                  subColor: trendColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  title: 'Units / Orders Sold',
                  value: '$packs Items',
                  sub: '${orders.length} checkout receipt${orders.length == 1 ? '' : 's'}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  title: 'Avg Basket Size',
                  value: '$symbol${avgBasket.toStringAsFixed(2)}',
                  sub: orders.isEmpty
                      ? 'No checkouts yet'
                      : '~${(packs / orders.length).toStringAsFixed(1)} items per purchase',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  title: 'Top Category',
                  value: topCat.isEmpty ? '—' : topCat.first.key,
                  sub: topCat.isEmpty
                      ? 'Sell to populate'
                      : '$symbol${topCat.first.value.toStringAsFixed(2)} sales',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 240,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.scaffold,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Revenue Overview ($periodTitle)',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            'From ${orders.length} sale${orders.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: orders.isEmpty
                            ? const Center(
                                child: Text(
                                  'No sales in this period yet.\nComplete a checkout to see the chart.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.slate400),
                                ),
                              )
                            : LineChart(
                                LineChartData(
                                  minY: 0,
                                  maxY: chartMax,
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (v) => FlLine(
                                      color: AppColors.slate200.withValues(alpha: 0.8),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 36,
                                        getTitlesWidget: (v, meta) => Text(
                                          v.toInt().toString(),
                                          style: const TextStyle(fontSize: 9, color: AppColors.slate400),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: _period == 'month' ? 5 : 1,
                                        getTitlesWidget: (v, meta) {
                                          final label = switch (_period) {
                                            'week' => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][v.toInt().clamp(0, 6)],
                                            'month' => v.toInt().toString(),
                                            _ => '${v.toInt()}h',
                                          };
                                          return Text(label, style: const TextStyle(fontSize: 9, color: AppColors.slate400));
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipItems: (touched) => [
                                        for (final t in touched)
                                          LineTooltipItem(
                                            '$symbol${t.y.toStringAsFixed(2)}',
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      isCurved: true,
                                      color: AppColors.restaurant,
                                      barWidth: 3,
                                      dotData: FlDotData(
                                        show: true,
                                        getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                                          radius: s.y > 0 ? 3.5 : 0,
                                          color: AppColors.restaurant,
                                          strokeWidth: 0,
                                        ),
                                      ),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppColors.restaurant.withValues(alpha: 0.18),
                                      ),
                                      spots: spots,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 240,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.scaffold,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: byPay.isEmpty
                            ? const Center(
                                child: Text(
                                  'No payments yet',
                                  style: TextStyle(fontSize: 12, color: AppColors.slate400),
                                ),
                              )
                            : PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 36,
                                  sections: [
                                    for (final e in byPay.entries)
                                      PieChartSectionData(
                                        value: e.value,
                                        color: switch (e.key) {
                                          PaymentMethod.cash => const Color(0xFFF97316),
                                          PaymentMethod.gcash => const Color(0xFF3B82F6),
                                          PaymentMethod.maya => const Color(0xFF10B981),
                                          PaymentMethod.card => const Color(0xFFA855F7),
                                        },
                                        title: '${e.key.label}\n$symbol${e.value.toStringAsFixed(0)}',
                                        titleStyle: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        radius: 48,
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.scaffold,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Which Products Sell Most (Best Sellers)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                const SizedBox(height: 10),
                if (best.isEmpty)
                  const Text(
                    'No sales in this period — complete a checkout to populate.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate400),
                  )
                else
                  for (var i = 0; i < best.take(5).length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            '#${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.slate400),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              best[i].key,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                          Text(
                            '${best[i].value} Units Sold',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.slate500,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
    required this.sub,
    this.subColor,
  });

  final String title;
  final String value;
  final String sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate500)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: subColor ?? AppColors.slate400)),
        ],
      ),
    );
  }
}
