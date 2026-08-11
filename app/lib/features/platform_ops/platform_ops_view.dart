import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/platform_models.dart';
import '../../data/providers/platform_providers.dart';
import '../../domain/enums.dart';

/// CasinPOS SaaS ops console — platform admins only.
class PlatformOpsView extends ConsumerStatefulWidget {
  const PlatformOpsView({super.key});

  @override
  ConsumerState<PlatformOpsView> createState() => _PlatformOpsViewState();
}

class _PlatformOpsViewState extends ConsumerState<PlatformOpsView> {
  final _search = TextEditingController();
  PlatformTenant? _selected;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(platformTenantsProvider);
    ref.invalidate(isPlatformAdminProvider);
  }

  @override
  Widget build(BuildContext context) {
    final adminAsync = ref.watch(isPlatformAdminProvider);
    final tenantsAsync = ref.watch(platformTenantsProvider);

    return ColoredBox(
      color: Colors.white,
      child: adminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (isAdmin) {
          if (!isAdmin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Platform Ops is only available to CasinPOS admins.\n'
                  'Ask an existing admin to promote your email, or run the promote SQL in docs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate600, height: 1.4),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final list = _TenantListPane(
                  searchController: _search,
                  tenantsAsync: tenantsAsync,
                  selectedId: _selected?.id,
                  expandList: wide,
                  onSearch: (q) {
                    ref.read(platformTenantSearchProvider.notifier).state = q;
                  },
                  onSelect: (t) => setState(() => _selected = t),
                  onRefresh: _refresh,
                );
                final detail = _selected == null
                    ? const _EmptyDetail()
                    : _TenantDetailPane(
                        tenant: _selected!,
                        onChanged: () async {
                          await _refresh();
                          final list = await ref.read(platformTenantsProvider.future);
                          final match = list.where((t) => t.id == _selected!.id).firstOrNull;
                          if (mounted) setState(() => _selected = match ?? _selected);
                        },
                      );

                if (!wide) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      list,
                      const SizedBox(height: 16),
                      SizedBox(height: 440, child: detail),
                    ],
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 380, child: list),
                      const SizedBox(width: 16),
                      Expanded(child: detail),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Text(
        'Select a store to manage plan or suspension',
        style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TenantListPane extends StatelessWidget {
  const _TenantListPane({
    required this.searchController,
    required this.tenantsAsync,
    required this.selectedId,
    required this.onSearch,
    required this.onSelect,
    required this.onRefresh,
    this.expandList = true,
  });

  final TextEditingController searchController;
  final AsyncValue<List<PlatformTenant>> tenantsAsync;
  final String? selectedId;
  final ValueChanged<String> onSearch;
  final ValueChanged<PlatformTenant> onSelect;
  final Future<void> Function() onRefresh;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    Widget body = tenantsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(friendlyError(e), textAlign: TextAlign.center),
      ),
      data: (tenants) {
        if (tenants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('No stores found', style: TextStyle(color: AppColors.slate500)),
            ),
          );
        }
        final tiles = [
          for (var i = 0; i < tenants.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final t = tenants[i];
                final selected = t.id == selectedId;
                return Material(
                  color: selected ? AppColors.accentSoft : AppColors.scaffold,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelect(t),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AppColors.accentDeep : AppColors.slate200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                              ),
                              if (t.isSuspended)
                                const _Pill(label: 'SUSPENDED', danger: true)
                              else
                                _Pill(
                                  label: t.planTier.value.toUpperCase(),
                                  danger: false,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.ownerEmail ?? t.ownerName ?? 'No owner email',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Usage ${t.transactionsThisPeriod}/${t.monthlyTransactionLimit}'
                            ' · ${t.activeMembers} members',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: t.usageRatio.clamp(0, 1),
                              minHeight: 4,
                              backgroundColor: AppColors.slate200,
                              color: t.usageRatio >= 1
                                  ? AppColors.danger
                                  : t.usageRatio >= 0.8
                                      ? AppColors.warning
                                      : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ];
        if (expandList) {
          return ListView(children: tiles);
        }
        return Column(children: tiles);
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Platform Ops',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Search customer stores by name, owner email, or store id',
          style: TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search tenants…',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: () => onSearch(searchController.text),
              icon: const Icon(Icons.search, size: 18),
            ),
          ),
          onChanged: null,
          onSubmitted: onSearch,
        ),
        const SizedBox(height: 12),
        if (expandList) Expanded(child: body) else body,
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.danger});

  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFEE2E2) : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: danger ? AppColors.danger : AppColors.accentDeep,
        ),
      ),
    );
  }
}

class _TenantDetailPane extends ConsumerStatefulWidget {
  const _TenantDetailPane({required this.tenant, required this.onChanged});

  final PlatformTenant tenant;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_TenantDetailPane> createState() => _TenantDetailPaneState();
}

class _TenantDetailPaneState extends ConsumerState<_TenantDetailPane> {
  var _busy = false;

  PlatformTenant get t => widget.tenant;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await widget.onChanged();
      if (mounted) showAppMessage(context, 'Updated');
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPlan(PlanTier plan) async {
    final limitCtrl = TextEditingController(
      text: plan == PlanTier.premium ? '100000' : '100',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set plan to ${plan.value}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Store: ${t.name}'),
            const SizedBox(height: 12),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Monthly transaction limit'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    final limit = int.tryParse(limitCtrl.text);
    limitCtrl.dispose();
    if (ok != true) return;
    await _run(() => ref.read(platformAdminRepositoryProvider).setStorePlan(
          storeId: t.id,
          plan: plan,
          monthlyLimit: limit,
        ));
  }

  Future<void> _toggleSuspend() async {
    final suspending = !t.isSuspended;
    final reasonCtrl = TextEditingController(text: t.suspensionReason ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suspending ? 'Suspend store?' : 'Reinstate store?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (suspending) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason (shown on blocked sales)',
                  hintText: 'e.g. Non-payment / abuse review',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: suspending
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(suspending ? 'Suspend' : 'Reinstate'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok != true) return;
    await _run(() => ref.read(platformAdminRepositoryProvider).setStoreSuspended(
          storeId: t.id,
          suspended: suspending,
          reason: reason.isEmpty ? null : reason,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy · h:mm a');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            t.id,
            style: const TextStyle(fontSize: 11, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),
          _kv('Owner', t.ownerName ?? '—'),
          _kv('Email', t.ownerEmail ?? '—'),
          _kv('Type', t.businessType.value),
          _kv('Plan', t.planTier.value),
          _kv('Subscription', t.subscriptionStatus ?? '—'),
          _kv('Usage', '${t.transactionsThisPeriod} / ${t.monthlyTransactionLimit} this period'),
          _kv('Members', '${t.activeMembers}'),
          _kv('Created', fmt.format(t.createdAt)),
          _kv(
            'Status',
            t.isSuspended
                ? 'Suspended ${t.suspendedAt != null ? fmt.format(t.suspendedAt!) : ''}'
                    '${t.suspensionReason != null ? ' — ${t.suspensionReason}' : ''}'
                : 'Active',
          ),
          const SizedBox(height: 20),
          const Text('Actions', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _setPlan(PlanTier.premium),
                child: const Text('Set Premium'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _setPlan(PlanTier.free),
                child: const Text('Set Free'),
              ),
              FilledButton(
                onPressed: _busy ? null : _toggleSuspend,
                style: FilledButton.styleFrom(
                  backgroundColor: t.isSuspended ? AppColors.success : AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: Text(t.isSuspended ? 'Reinstate' : 'Suspend'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
