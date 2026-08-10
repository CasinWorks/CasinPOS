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

/// Stack analytics below this screen width (phone + most tablets in portrait).
const _stackLayoutMaxWidth = 900.0;

/// Bottom inset so the shell Cart FAB never covers the last list rows.
const _cartFabClearance = 112.0;

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

  /// Prefer MediaQuery; fall back to LayoutBuilder if width is finite.
  bool _useStackedLayout(double screenWidth, BoxConstraints constraints) {
    final contentW = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : screenWidth;
    final effective = contentW < screenWidth ? contentW : screenWidth;
    return effective < _stackLayoutMaxWidth;
  }

  Widget _periodChips({required bool wrap}) {
    final chips = TutorialTarget(
      anchor: TutorialAnchor.analyticsPeriod,
      child: wrap
          ? Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in ['today', 'week', 'month']) _periodChip(p),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in ['today', 'week', 'month']) ...[
                  _periodChip(p),
                  const SizedBox(width: 6),
                ],
              ],
            ),
    );
    return chips;
  }

  Widget _periodChip(String p) {
    return ChoiceChip(
      label: Text(
        p == 'today'
            ? 'Daily Today'
            : p == 'week'
                ? 'This Week'
                : 'This Month',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _period == p ? AppColors.slate900 : Colors.white70,
        ),
      ),
      selected: _period == p,
      selectedColor: AppColors.retail,
      backgroundColor: const Color(0xFF1E293B),
      onSelected: (_) => setState(() => _period = p),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _header({
    required bool stacked,
    required VoidCallback onExportPdf,
  }) {
    final pdfButton = IconButton(
      tooltip: 'Export owner report PDF',
      onPressed: onExportPdf,
      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );

    if (stacked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: BoxDecoration(
          color: AppColors.slate900,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Sales Analytics & Best Sellers',
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
                ),
                pdfButton,
              ],
            ),
            const SizedBox(height: 10),
            _periodChips(wrap: true),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
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
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          pdfButton,
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: _periodChips(wrap: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid({
    required bool stacked,
    required List<Widget> metrics,
  }) {
    if (stacked) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: metrics,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: metrics[i]),
        ],
      ],
    );
  }

  Widget _chartsSection({
    required bool stacked,
    required String periodTitle,
    required List<PosOrder> orders,
    required String symbol,
    required double chartMax,
    required List<FlSpot> spots,
    required Map<PaymentMethod, double> byPay,
  }) {
    final revenue = _RevenueChartCard(
      periodTitle: periodTitle,
      orders: orders,
      symbol: symbol,
      chartMax: chartMax,
      spots: spots,
      period: _period,
      stacked: stacked,
    );
    final payments = _PaymentMethodsCard(
      byPay: byPay,
      symbol: symbol,
      stacked: stacked,
    );

    // Never place charts in a side-by-side Row on narrow screens —
    // Expanded flex collapses and paints pie over the line chart.
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          revenue,
          const SizedBox(height: 12),
          payments,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: revenue),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: payments),
      ],
    );
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
    final prevAvgBasket = prevOrders.isEmpty
        ? 0.0
        : prevOrders.fold<double>(0, (s, o) => s + o.total) / prevOrders.length;

    String trendLabel;
    Color? trendColor;
    double? revenueTrendPct;
    if (prevRevenue <= 0 && revenue <= 0) {
      trendLabel = 'No prior period data';
      trendColor = AppColors.slate400;
    } else if (prevRevenue <= 0) {
      trendLabel = 'New sales this period';
      trendColor = AppColors.success;
      revenueTrendPct = 100;
    } else {
      final pct = ((revenue - prevRevenue) / prevRevenue) * 100;
      revenueTrendPct = pct;
      final sign = pct >= 0 ? '+' : '';
      trendLabel = '$sign${pct.toStringAsFixed(1)}% vs previous $_period';
      trendColor = pct >= 0 ? AppColors.success : AppColors.danger;
    }

    double? basketTrendPct;
    if (prevAvgBasket > 0) {
      basketTrendPct = ((avgBasket - prevAvgBasket) / prevAvgBasket) * 100;
    } else if (avgBasket > 0) {
      basketTrendPct = 100;
    }

    final revenueSpark = _metricSparkline(orders, _period, (o) => o.total);
    final basketSpark = _metricSparkline(
      orders,
      _period,
      (o) => o.total, // period buckets; avg visualized via same cadence
      asAverage: true,
    );

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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = _useStackedLayout(screenWidth, constraints);

            return ListView(
              padding: EdgeInsets.fromLTRB(
                stacked ? 16 : 20,
                16,
                stacked ? 16 : 20,
                24 + _cartFabClearance + bottomInset,
              ),
              children: [
                _header(
                  stacked: stacked,
                  onExportPdf: () => _exportPdf(orders: orders, start: start, end: end),
                ),
                const SizedBox(height: 12),
                _metricsGrid(
                  stacked: stacked,
                  metrics: [
                    _Metric(
                      title: 'Total Revenue',
                      value: '$symbol${revenue.toStringAsFixed(2)}',
                      sub: trendLabel,
                      subColor: trendColor,
                      stacked: stacked,
                      sparkline: revenueSpark,
                      trendPct: revenueTrendPct,
                    ),
                    _Metric(
                      title: 'Units / Orders Sold',
                      value: '$packs Items',
                      sub: '${orders.length} checkout receipt${orders.length == 1 ? '' : 's'}',
                      stacked: stacked,
                    ),
                    _Metric(
                      title: 'Avg Basket Size',
                      value: '$symbol${avgBasket.toStringAsFixed(2)}',
                      sub: orders.isEmpty
                          ? 'No checkouts yet'
                          : '~${(packs / orders.length).toStringAsFixed(1)} items per purchase',
                      stacked: stacked,
                      sparkline: basketSpark,
                      trendPct: basketTrendPct,
                    ),
                    _Metric(
                      title: 'Top Category',
                      value: topCat.isEmpty ? '—' : topCat.first.key,
                      sub: topCat.isEmpty
                          ? 'Sell to populate'
                          : '$symbol${topCat.first.value.toStringAsFixed(2)} sales',
                      stacked: stacked,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _chartsSection(
                  stacked: stacked,
                  periodTitle: periodTitle,
                  orders: orders,
                  symbol: symbol,
                  chartMax: chartMax,
                  spots: spots,
                  byPay: byPay,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
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
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.slate400,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    best[i].key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
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
            );
          },
        ),
      ),
    );
  }
}

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({
    required this.periodTitle,
    required this.orders,
    required this.symbol,
    required this.chartMax,
    required this.spots,
    required this.period,
    required this.stacked,
  });

  final String periodTitle;
  final List<PosOrder> orders;
  final String symbol;
  final double chartMax;
  final List<FlSpot> spots;
  final String period;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final chart = orders.isEmpty
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
                    reservedSize: 32,
                    getTitlesWidget: (v, meta) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 9, color: AppColors.slate400),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: period == 'month' ? 5 : 1,
                    getTitlesWidget: (v, meta) {
                      final label = switch (period) {
                        'week' => const [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ][v.toInt().clamp(0, 6)],
                        'month' => v.toInt().toString(),
                        _ => '${v.toInt()}h',
                      };
                      return Text(
                        label,
                        style: const TextStyle(fontSize: 9, color: AppColors.slate400),
                      );
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
                  color: AppColors.accent,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: s.y > 0 ? 3.5 : 0,
                      color: AppColors.accent,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.accent.withValues(alpha: 0.18),
                  ),
                  spots: spots,
                ),
              ],
            ),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Overview ($periodTitle)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            'From ${orders.length} sale${orders.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 10, color: AppColors.slate400),
          ),
          const SizedBox(height: 12),
          if (stacked)
            AspectRatio(aspectRatio: 1.6, child: chart)
          else
            SizedBox(height: 200, child: chart),
        ],
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard({
    required this.byPay,
    required this.symbol,
    required this.stacked,
  });

  final Map<PaymentMethod, double> byPay;
  final String symbol;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final chart = byPay.isEmpty
        ? const Center(
            child: Text(
              'No payments yet',
              style: TextStyle(fontSize: 12, color: AppColors.slate400),
            ),
          )
        : FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 200,
              height: 200,
              child: PieChart(
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
          );

    return Container(
      width: double.infinity,
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
            'Payment Methods',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (stacked)
            SizedBox(
              height: 220,
              width: double.infinity,
              child: chart,
            )
          else
            SizedBox(height: 180, child: chart),
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
    this.stacked = false,
    this.sparkline,
    this.trendPct,
  });

  final String title;
  final String value;
  final String sub;
  final Color? subColor;
  final bool stacked;
  final List<double>? sparkline;
  final double? trendPct;

  @override
  Widget build(BuildContext context) {
    final arrowUp = trendPct != null && trendPct! >= 0;
    final arrowColor = trendPct == null
        ? AppColors.slate400
        : arrowUp
            ? AppColors.success
            : AppColors.danger;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(stacked ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
              ),
              if (trendPct != null)
                Icon(
                  arrowUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 18,
                  color: arrowColor,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: stacked ? 15 : 16,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          if (sparkline != null && sparkline!.length >= 2) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: sparkline!,
                  color: arrowColor == AppColors.slate400 ? AppColors.accent : arrowColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            sub,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: subColor ?? AppColors.slate400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

/// Buckets order values across the active period for metric sparklines.
List<double> _metricSparkline(
  List<PosOrder> orders,
  String period,
  double Function(PosOrder) valueOf, {
  bool asAverage = false,
}) {
  if (period == 'today') {
    final sums = List<double>.filled(24, 0);
    final counts = List<int>.filled(24, 0);
    for (final o in orders) {
      final h = o.createdAt.hour;
      sums[h] += valueOf(o);
      counts[h] += 1;
    }
    final start = 8;
    final end = 22;
    return [
      for (var h = start; h <= end; h++)
        asAverage ? (counts[h] == 0 ? 0.0 : sums[h] / counts[h]) : sums[h],
    ];
  }

  if (period == 'week') {
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (final o in orders) {
      final i = o.createdAt.weekday - 1;
      sums[i] += valueOf(o);
      counts[i] += 1;
    }
    return [
      for (var i = 0; i < 7; i++)
        asAverage ? (counts[i] == 0 ? 0.0 : sums[i] / counts[i]) : sums[i],
    ];
  }

  final now = DateTime.now();
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final sums = List<double>.filled(daysInMonth, 0);
  final counts = List<int>.filled(daysInMonth, 0);
  for (final o in orders) {
    final d = o.createdAt.day - 1;
    if (d >= 0 && d < daysInMonth) {
      sums[d] += valueOf(o);
      counts[d] += 1;
    }
  }
  return [
    for (var i = 0; i < daysInMonth; i++)
      asAverage ? (counts[i] == 0 ? 0.0 : sums[i] / counts[i]) : sums[i],
  ];
}
