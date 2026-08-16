import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/report_models.dart';
import '../../../data/providers/report_providers.dart';
import '../../../data/providers/session_providers.dart';

/// Shared branch + date filters for all report screens.
class ReportScopeBar extends ConsumerWidget {
  const ReportScopeBar({super.key, this.showDateRange = true});

  final bool showDateRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    final branchesAsync = ref.watch(storeBranchesProvider);
    final selected = ref.watch(reportBranchScopeProvider);
    final range = ref.watch(reportDateRangeProvider);
    final canSelect = membership?.role.canSelectBranchScope == true;
    final branches = branchesAsync.valueOrNull ?? const <StoreBranch>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (canSelect)
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                key: ValueKey(selected ?? 'all'),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Branches'),
                  ),
                  for (final b in branches)
                    DropdownMenuItem<String?>(
                      value: b.id,
                      child: Text(
                        b.isPrimary ? '${b.name} (Main)' : b.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) =>
                    ref.read(reportBranchScopeProvider.notifier).state = v,
              ),
            )
          else if (membership?.role.isBranchScoped == true)
            Chip(
              avatar: const Icon(Icons.store_mall_directory_outlined, size: 16),
              label: Text(
                branches
                        .where((b) => b.id == (selected ?? membership?.branchIds.firstOrNull))
                        .map((b) => b.name)
                        .firstOrNull ??
                    'Your branch',
              ),
            ),
          if (showDateRange) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: DateTimeRange(
                    start: range.start,
                    end: range.end.subtract(const Duration(days: 1)),
                  ),
                );
                if (picked == null) return;
                ref.read(reportDateRangeProvider.notifier).state = (
                  start: DateTime(
                    picked.start.year,
                    picked.start.month,
                    picked.start.day,
                  ),
                  end: DateTime(
                    picked.end.year,
                    picked.end.month,
                    picked.end.day,
                  ).add(const Duration(days: 1)),
                );
              },
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                '${DateFormat('MMM d').format(range.start)} – '
                '${DateFormat('MMM d').format(range.end.subtract(const Duration(days: 1)))}',
              ),
            ),
            TextButton(
              onPressed: () {
                final end = DateTime.now();
                final start = DateTime(end.year, end.month, end.day)
                    .subtract(const Duration(days: 6));
                ref.read(reportDateRangeProvider.notifier).state = (
                  start: start,
                  end: end.add(const Duration(days: 1)),
                );
              },
              child: const Text('Last 7 days'),
            ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
