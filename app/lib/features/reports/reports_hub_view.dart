import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_errors.dart';
import '../../core/export/export_text_file.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/report_models.dart';
import '../../data/providers/report_providers.dart';
import 'report_scope_bar.dart';

class ReportsHubView extends ConsumerStatefulWidget {
  const ReportsHubView({super.key});

  @override
  ConsumerState<ReportsHubView> createState() => _ReportsHubViewState();
}

class _ReportsHubViewState extends ConsumerState<ReportsHubView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canView = ref.watch(canViewReportsProvider);
    if (!canView) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Reports are available to Owner, Admin, Manager, and Branch Manager.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Reports & Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const ReportScopeBar(),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: AppColors.slate900,
            unselectedLabelColor: AppColors.slate500,
            indicatorColor: AppColors.accent,
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Inventory'),
              Tab(text: 'Sales'),
              Tab(text: 'Profitability'),
              Tab(text: 'Trends'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _DashboardTab(),
                _InventoryTab(),
                _SalesTab(),
                _ProfitTab(),
                _TrendsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _exportCsv(
  BuildContext context, {
  required String content,
  required String filename,
}) async {
  await exportTextFile(content: content, filename: filename);
  if (context.mounted) {
    showAppMessage(context, 'CSV copied${filename.isNotEmpty ? ' · $filename' : ''}');
  }
}

String _branchLabel(WidgetRef ref) {
  final id = ref.read(effectiveReportBranchIdProvider);
  if (id == null) return 'all';
  final branches = ref.read(storeBranchesProvider).valueOrNull ?? const [];
  for (final b in branches) {
    if (b.id == id) return b.name;
  }
  return 'branch';
}

({DateTime start, DateTime end}) _range(WidgetRef ref) =>
    ref.read(reportDateRangeProvider);

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportDashboardProvider);
    final money = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (stats) {
        if (stats == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Revenue',
                  value: money.format(stats.revenue),
                  changePct: stats.revenueChangePct,
                ),
                _MetricCard(
                  label: 'Units sold',
                  value: NumberFormat.compact().format(stats.unitsSold),
                  changePct: stats.unitsChangePct,
                ),
                _MetricCard(
                  label: 'Transactions',
                  value: '${stats.transactions}',
                ),
                _MetricCard(
                  label: 'Inventory value',
                  value: money.format(stats.inventoryValue),
                ),
                _MetricCard(
                  label: 'Low stock',
                  value: '${stats.lowStockCount}',
                ),
                _MetricCard(
                  label: 'Dead stock (30d)',
                  value: '${stats.deadStockCount}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Top products', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: stats.topProducts.isEmpty
                  ? const Center(child: Text('No sales in this period'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= stats.topProducts.length) {
                                  return const SizedBox.shrink();
                                }
                                final name = stats.topProducts[i].itemName;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    name.length > 8 ? '${name.substring(0, 8)}…' : name,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < stats.topProducts.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: stats.topProducts[i].revenue,
                                  color: AppColors.accent,
                                  width: 14,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                        ],
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
            if (stats.byBranch.length > 1) ...[
              const SizedBox(height: 20),
              const Text(
                'Per-branch breakdown',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final b in stats.byBranch)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.branchName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${b.transactions} sales · ${b.unitsSold.toStringAsFixed(0)} units'),
                  trailing: Text(
                    money.format(b.revenue),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.changePct,
  });

  final String label;
  final String value;
  final double? changePct;

  @override
  Widget build(BuildContext context) {
    final change = changePct;
    Color? changeColor;
    String? changeText;
    if (change != null) {
      changeColor = change >= 0 ? const Color(0xFF059669) : AppColors.danger;
      changeText = '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% vs prior';
    }
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (changeText != null) ...[
            const SizedBox(height: 4),
            Text(changeText, style: TextStyle(fontSize: 10, color: changeColor, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _InventoryTab extends ConsumerStatefulWidget {
  const _InventoryTab();

  @override
  ConsumerState<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends ConsumerState<_InventoryTab> {
  var _lowOnly = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inventoryReportProvider(_lowOnly));
    final includeBranch = ref.watch(includeBranchColumnInExportProvider);
    final money = NumberFormat('0.00');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Low stock only'),
                selected: _lowOnly,
                onSelected: (v) => setState(() => _lowOnly = v),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: async.valueOrNull == null
                    ? null
                    : () async {
                        final rows = async.valueOrNull ?? const [];
                        final range = _range(ref);
                        await _exportCsv(
                          context,
                          content: ReportCsv.inventory(
                            rows: rows,
                            includeBranch: includeBranch,
                          ),
                          filename: ReportCsv.filename(
                            report: 'inventory',
                            branchOrAll: _branchLabel(ref),
                            start: range.start,
                            end: range.end.subtract(const Duration(days: 1)),
                          ),
                        );
                      },
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('CSV'),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyError(e))),
            data: (rows) {
              if (rows.isEmpty) {
                return const Center(child: Text('No inventory rows'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = rows[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${r.sku.isEmpty ? '—' : r.sku} · ${r.category}'
                      '${includeBranch ? ' · ${r.branchName}' : ''}'
                      '${r.supplier == null || r.supplier!.isEmpty ? '' : ' · ${r.supplier}'}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Stock ${r.currentStock.toStringAsFixed(r.currentStock == r.currentStock.roundToDouble() ? 0 : 1)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: r.lowStockFlag ? AppColors.danger : AppColors.slate900,
                          ),
                        ),
                        Text(
                          'Value ${money.format(r.stockValue)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesLineReportProvider);
    final includeBranch = ref.watch(includeBranchColumnInExportProvider);
    final money = NumberFormat('0.00');

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: async.valueOrNull == null
                ? null
                : () async {
                    final rows = async.valueOrNull ?? const [];
                    final range = _range(ref);
                    await _exportCsv(
                      context,
                      content: ReportCsv.salesLines(
                        rows: rows,
                        includeBranch: includeBranch,
                      ),
                      filename: ReportCsv.filename(
                        report: 'sales',
                        branchOrAll: _branchLabel(ref),
                        start: range.start,
                        end: range.end.subtract(const Duration(days: 1)),
                      ),
                    );
                  },
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('CSV'),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyError(e))),
            data: (rows) {
              if (rows.isEmpty) {
                return const Center(child: Text('No sales lines in this range'));
              }
              final byCategory = <String, double>{};
              for (final r in rows) {
                byCategory[r.category] =
                    (byCategory[r.category] ?? 0) + r.lineTotal;
              }
              final pieEntries = byCategory.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final pieTop = pieEntries.take(6).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (pieTop.isNotEmpty) ...[
                    const Text('By category', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 32,
                          sections: [
                            for (var i = 0; i < pieTop.length; i++)
                              PieChartSectionData(
                                value: pieTop[i].value,
                                title: pieTop[i].key.length > 8
                                    ? '${pieTop[i].key.substring(0, 8)}…'
                                    : pieTop[i].key,
                                radius: 48,
                                titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                                color: [
                                  AppColors.accent,
                                  const Color(0xFF0EA5E9),
                                  const Color(0xFF10B981),
                                  const Color(0xFFF59E0B),
                                  const Color(0xFF8B5CF6),
                                  const Color(0xFFEF4444),
                                ][i % 6],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final r in rows.take(200))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(r.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${DateFormat('MMM d').format(r.date)} ${r.time}'
                        '${includeBranch ? ' · ${r.branchName}' : ''}'
                        ' · ${r.paymentMethod} · ${r.staffName}',
                      ),
                      trailing: Text(
                        money.format(r.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  if (rows.length > 200)
                    Text(
                      'Showing first 200 of ${rows.length} lines — export CSV for full data.',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfitTab extends ConsumerWidget {
  const _ProfitTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profitabilityReportProvider);
    final includeBranch = ref.watch(includeBranchColumnInExportProvider);
    final money = NumberFormat('0.00');

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: async.valueOrNull == null
                ? null
                : () async {
                    final rows = async.valueOrNull ?? const [];
                    final range = _range(ref);
                    await _exportCsv(
                      context,
                      content: ReportCsv.profitability(
                        rows: rows,
                        includeBranch: includeBranch,
                      ),
                      filename: ReportCsv.filename(
                        report: 'profitability',
                        branchOrAll: _branchLabel(ref),
                        start: range.start,
                        end: range.end.subtract(const Duration(days: 1)),
                      ),
                    );
                  },
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('CSV'),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyError(e))),
            data: (rows) {
              if (rows.isEmpty) {
                return const Center(
                  child: Text(
                    'No profitability data. Set Cost (unit cost) on products for COGS/margin.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final top = rows.take(8).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Top by gross profit',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= top.length) {
                                  return const SizedBox.shrink();
                                }
                                final name = top[i].itemName;
                                return Text(
                                  name.length > 8 ? '${name.substring(0, 8)}…' : name,
                                  style: const TextStyle(fontSize: 9),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < top.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: top[i].grossProfit,
                                  color: const Color(0xFF059669),
                                  width: 14,
                                ),
                              ],
                            ),
                        ],
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final r in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.slate100,
                        child: Text('#${r.rank}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                      title: Text(r.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${r.category}${includeBranch ? ' · ${r.branchName}' : ''} · '
                        '${r.unitsSold.toStringAsFixed(0)} sold · margin ${r.marginPct.toStringAsFixed(1)}%',
                      ),
                      trailing: Text(
                        money.format(r.grossProfit),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportDashboardProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (stats) {
        if (stats == null || stats.byDay.isEmpty) {
          return const Center(child: Text('No trend data for this range'));
        }
        final points = stats.byDay;
        final maxY = points.fold<double>(0, (m, p) => p.revenue > m ? p.revenue : m);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MetricCard(
              label: 'Revenue vs prior period',
              value: NumberFormat.currency(symbol: '₱', decimalDigits: 0).format(stats.revenue),
              changePct: stats.revenueChangePct,
            ),
            const SizedBox(height: 12),
            _MetricCard(
              label: 'Units vs prior period',
              value: NumberFormat.compact().format(stats.unitsSold),
              changePct: stats.unitsChangePct,
            ),
            const SizedBox(height: 20),
            const Text('Revenue over time', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 1 : maxY * 1.15,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (points.length / 4).clamp(1, 7).toDouble(),
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) return const SizedBox.shrink();
                          return Text(
                            DateFormat('M/d').format(points[i].day),
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].revenue),
                      ],
                      isCurved: true,
                      color: AppColors.accent,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Units over time', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (points.length / 4).clamp(1, 7).toDouble(),
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) return const SizedBox.shrink();
                          return Text(
                            DateFormat('M/d').format(points[i].day),
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].unitsSold,
                            color: const Color(0xFF0EA5E9),
                            width: 10,
                          ),
                        ],
                      ),
                  ],
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
