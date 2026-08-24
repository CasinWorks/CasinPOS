import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/service_providers.dart';
import '../reports/report_scope_bar.dart';

class ServiceReportsView extends ConsumerWidget {
  const ServiceReportsView({super.key, this.embedded = false});

  /// When true, omit the page title and date bar (already shown by Reports hub).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceReportStatsProvider);
    final money = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
    final body = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyError(e))),
      data: (stats) {
        if (stats == null) {
          return const Center(
            child: Text('Reports are available to Owner, Admin, Manager, and Branch Manager.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Card(label: 'Collected revenue', value: money.format(stats.collectedRevenue)),
                _Card(label: 'Paid jobs', value: '${stats.paidJobs}'),
                _Card(label: 'Conversion', value: '${stats.conversionRate}%'),
                _Card(label: 'Quotes sent', value: '${stats.quotesSent}'),
                _Card(label: 'Accepted', value: '${stats.quotesAccepted}'),
                _Card(
                  label: 'Avg quote',
                  value: money.format(stats.averageQuoteValue),
                ),
                _Card(label: 'Outstanding quotes', value: '${stats.outstandingQuotes}'),
                _Card(
                  label: 'Outstanding deposits',
                  value: money.format(stats.outstandingDeposits),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Revenue by service',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (stats.revenueByService.isEmpty)
              const Text('No paid service jobs in this period.')
            else
              ...stats.revenueByService.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.name),
                  subtitle: Text('${r.units.toStringAsFixed(0)} booked'),
                  trailing: Text(
                    money.format(r.revenue),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (embedded) return ColoredBox(color: Colors.white, child: body);

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Service reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const ReportScopeBar(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
