import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_errors.dart';
import '../../core/responsive/adaptive_scaffold.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/providers/session_providers.dart';
import '../../domain/enums.dart';
import '../billing/billing_providers.dart';
import '../settings/store_settings_dialog.dart';
import '../team/invite_teammate_dialog.dart';

/// Restaurant shell placeholder until the restaurant suite ships.
class Phase1HomePage extends ConsumerStatefulWidget {
  const Phase1HomePage({super.key});

  @override
  ConsumerState<Phase1HomePage> createState() => _Phase1HomePageState();
}

class _Phase1HomePageState extends ConsumerState<Phase1HomePage> {
  String? _tab;
  bool _switching = false;
  String? _switchError;

  Future<void> _switchToRetail() async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null) return;
    setState(() {
      _switching = true;
      _switchError = null;
    });
    try {
      await ref.read(storeRepositoryProvider).updateBusinessType(
            storeId: membership.storeId,
            businessType: BusinessType.retail,
          );
      ref.invalidate(membershipsProvider);
    } catch (e) {
      if (mounted) {
        setState(
          () => _switchError = friendlyError(
            e,
            fallback: 'Couldn’t switch to retail. Check your connection and try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(premiumAutoSyncProvider);
    final membership = ref.watch(activeMembershipProvider);
    final type = membership?.store.businessType ?? BusinessType.restaurant;
    final destinations = _destinationsFor(type);
    final selected = _tab ?? destinations.first.id;
    final canSwitch =
        membership != null && membership.role.canInviteUsers && type == BusinessType.restaurant;

    return AdaptiveScaffold(
      destinations: destinations,
      selectedId: selected,
      onSelect: (id) => setState(() => _tab = id),
      brandHeader: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrandMark(businessType: type),
          const SizedBox(height: AppSpacing.md),
          if (membership != null)
            InkWell(
              onTap: () => showStoreSettingsDialog(context, ref),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.store.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13),
                    ),
                    Text(
                      '${type.value} · ${membership.role.value} · '
                      '${membership.store.currencySymbol} · tap for settings',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              'Design preview (no store session)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
      footer: membership == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (membership.role.canInviteUsers)
                  OutlinedButton.icon(
                    onPressed: () => showInviteTeammateDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Invite teammate'),
                  ),
                TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(authRepositoryProvider).signOut();
                    } catch (_) {}
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
      cartTray: const _CartTrayPlaceholder(),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (canSwitch) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Wrong business type?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Restaurant POS is still coming. If you meant to run retail checkout & inventory, switch now — this cannot be undone.',
                    style: TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.35),
                  ),
                  if (_switchError != null) ...[
                    const SizedBox(height: 8),
                    Text(_switchError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _switching ? null : _switchToRetail,
                    icon: _switching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.storefront_rounded, size: 18),
                    label: Text(_switching ? 'Switching…' : 'Switch permanently to Retail'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          _PreviewBody(
            tab: selected,
            type: type,
            storeName: membership?.store.name,
            plan: membership?.store.planTier,
            usedTx: membership?.store.transactionsThisPeriod,
            limitTx: membership?.store.monthlyTransactionLimit,
          ),
        ],
      ),
    );
  }

  List<ShellDestination> _destinationsFor(BusinessType type) {
    if (type == BusinessType.restaurant) {
      return const [
        (id: 'floor_plan', label: 'Floor plan', icon: Icons.grid_view_rounded, badge: null),
        (id: 'dishes', label: 'Dishes Menu', icon: Icons.restaurant_menu_rounded, badge: null),
        (id: 'orders', label: 'Active Orders', icon: Icons.bookmark_rounded, badge: null),
        (id: 'bookings', label: 'Table Bookings', icon: Icons.calendar_month_rounded, badge: null),
        (id: 'receipts', label: 'Receipts', icon: Icons.receipt_long_rounded, badge: null),
        (id: 'analytics', label: 'Sales Statistics', icon: Icons.trending_up_rounded, badge: null),
      ];
    }
    return const [
      (id: 'checkout', label: 'Retail POS', icon: Icons.shopping_bag_rounded, badge: null),
      (id: 'inventory', label: 'Store Inventory', icon: Icons.inventory_2_rounded, badge: null),
      (id: 'orders', label: 'Sales History', icon: Icons.bookmark_rounded, badge: null),
      (id: 'receipts', label: 'Receipts Audit', icon: Icons.receipt_long_rounded, badge: null),
      (id: 'analytics', label: 'Sales Statistics', icon: Icons.trending_up_rounded, badge: null),
    ];
  }
}

class _CartTrayPlaceholder extends StatelessWidget {
  const _CartTrayPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.slate200)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Active order', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cart checkout arrives in the next POS phase.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.tab,
    required this.type,
    this.storeName,
    this.plan,
    this.usedTx,
    this.limitTx,
  });

  final String tab;
  final BusinessType type;
  final String? storeName;
  final PlanTier? plan;
  final int? usedTx;
  final int? limitTx;

  @override
  Widget build(BuildContext context) {
    final ff = context.formFactor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          storeName ??
              (type == BusinessType.restaurant ? 'Restaurant workspace' : 'Retail workspace'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Selected: $tab · ${ff.name} · '
          'Plan: ${plan?.value ?? '—'} · '
          'Usage: ${usedTx ?? 0}/${limitTx ?? AppConstants.freeMonthlyTransactionLimit} tx this month',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: const [
            _Pill(label: 'Breakfast', bg: AppColors.catBreakfast),
            _Pill(label: 'Lunch', bg: AppColors.catLunch),
            _Pill(label: 'Pastry', bg: AppColors.catPastry),
            _Pill(label: 'Soups', bg: AppColors.catSoups),
            _Pill(label: 'Bowls', bg: AppColors.catBowls),
            _Pill(label: 'Burgers', bg: AppColors.catBurgers),
            _Pill(label: 'Desserts', bg: AppColors.catDesserts),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.scaffold,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Text(
            type == BusinessType.restaurant
                ? 'Restaurant workspace is a placeholder for now. Menu, floor plan, and bookings land in a later phase.'
                : 'Retail POS is ready — use Switch permanently to Retail above if you still see this restaurant shell.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg});

  final String label;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
