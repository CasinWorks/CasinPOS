import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/display/open_customer_display.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/powered_by_casinworks.dart';
import '../../../data/providers/connectivity_providers.dart';
import '../../../data/providers/platform_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../data/providers/sync_providers.dart';
import '../../../domain/enums.dart';
import '../../../domain/permissions.dart';
import '../franchise/franchise_dialog.dart';
import '../onboarding/story_mode.dart';
import '../onboarding/tutorial_anchors.dart';
import '../settings/store_settings_dialog.dart';
import '../team/invite_teammate_dialog.dart';

class CasinPosSidebar extends ConsumerWidget {
  const CasinPosSidebar({
    super.key,
    required this.activeTab,
    required this.onSelectTab,
    required this.orderCount,
  });

  final String activeTab;
  final ValueChanged<String> onSelectTab;
  final int orderCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    final storeName = membership?.store.name ?? 'My Store';
    final type = membership?.store.businessType ?? BusinessType.retail;
    final role = membership?.role.value ?? 'staff';
    final pendingSync = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final online = ref.watch(connectivityOnlineProvider).valueOrNull ?? true;
    final isPlatformAdmin = ref.watch(isPlatformAdminProvider).valueOrNull ?? false;
    String userName = 'Team member';
    try {
      final user = ref.watch(authRepositoryProvider).currentUser;
      userName = (user?.userMetadata?['full_name'] as String?) ??
          user?.email ??
          'Team member';
    } catch (_) {}

    final items = <({String id, String label, IconData icon, int? badge})>[
      (id: 'checkout', label: 'Retail POS', icon: Icons.point_of_sale_rounded, badge: null),
      (id: 'inventory', label: 'Store Inventory', icon: Icons.inventory_2_outlined, badge: null),
      (id: 'register', label: 'Cash Register', icon: Icons.account_balance_wallet_outlined, badge: null),
      (id: 'orders', label: 'Sales History', icon: Icons.bookmark_outline, badge: orderCount),
      (id: 'receipts', label: 'Receipts Audit', icon: Icons.receipt_long_outlined, badge: null),
      (id: 'analytics', label: 'Sales Statistics', icon: Icons.trending_up, badge: null),
    ];

    return ColoredBox(
      color: AppColors.scaffold,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.slate200)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: BrandMark(businessType: type, compact: true)),
                  IconButton(
                    tooltip: 'Replay story tutorial',
                    onPressed: () => startRetailStory(ref),
                    icon: const Icon(Icons.auto_awesome, size: 18, color: AppColors.restaurant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Active Store:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.slate500),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        storeName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: online
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: online
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFED7AA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      size: 16,
                      color: online ? const Color(0xFF047857) : const Color(0xFFC2410C),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        online
                            ? (pendingSync > 0
                                ? 'Online · syncing $pendingSync'
                                : 'Online · synced')
                            : 'Offline · sales stay on this tablet',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: online
                              ? const Color(0xFF065F46)
                              : const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                    if (pendingSync > 0 && online)
                      IconButton(
                        tooltip: 'Sync now',
                        onPressed: () =>
                            ref.read(syncOutboxServiceProvider).flush(),
                        icon: const Icon(Icons.sync, size: 16),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                membership?.store.isFranchise == true
                    ? (type == BusinessType.retail
                        ? 'Retail franchise · locked'
                        : 'Restaurant franchise · locked')
                    : (type == BusinessType.retail ? 'Retail · locked' : 'Restaurant · locked'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _anchoredNav(
                          id: item.id,
                          child: _NavItem(
                            label: item.label,
                            icon: item.icon,
                            selected: activeTab == item.id,
                            badge: item.badge,
                            onTap: () => onSelectTab(item.id),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Divider(height: 24),
                    const Text(
                      'SYSTEM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.slate400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _NavItem(
                      label: 'Store Settings',
                      icon: Icons.settings_outlined,
                      selected: false,
                      onTap: () => showStoreSettingsDialog(context, ref),
                    ),
                    if (membership != null &&
                        Permissions.canOpenFranchise(
                          membership.role,
                          storeIsFranchise: membership.store.isFranchise,
                        ))
                      _NavItem(
                        label: 'Franchise',
                        icon: Icons.storefront_outlined,
                        selected: false,
                        onTap: () => showFranchiseDialog(context, ref),
                      ),
                    _NavItem(
                      label: 'Customer Display',
                      icon: Icons.tv_outlined,
                      selected: false,
                      onTap: () async {
                        final ok = await openCustomerDisplayWindow();
                        if (!context.mounted) return;
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open customer display'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    _NavItem(
                      label: 'Notifications',
                      icon: Icons.notifications_none_rounded,
                      selected: activeTab == 'notifications',
                      onTap: () => onSelectTab('notifications'),
                    ),
                    _NavItem(
                      label: 'Support',
                      icon: Icons.help_outline_rounded,
                      selected: activeTab == 'support',
                      onTap: () => onSelectTab('support'),
                    ),
                    if (isPlatformAdmin)
                      _NavItem(
                        label: 'Platform Ops',
                        icon: Icons.admin_panel_settings_outlined,
                        selected: activeTab == 'ops',
                        onTap: () => onSelectTab('ops'),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate100.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.slate300,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    Text(role, style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
                    const SizedBox(height: 8),
                    if (membership?.role.canInviteUsers == true)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => showInviteTeammateDialog(context, ref),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                          child: const Text('Invite / Manage'),
                        ),
                      ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref.read(authRepositoryProvider).signOut();
                        } catch (_) {}
                        if (context.mounted) context.go('/login');
                      },
                      child: const Text('Sign out', style: TextStyle(fontSize: 11)),
                    ),
                    const PoweredByCasinworks(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _anchoredNav({required String id, required Widget child}) {
    final anchor = switch (id) {
      'inventory' => TutorialAnchor.navInventory,
      'checkout' => TutorialAnchor.navPos,
      'receipts' => TutorialAnchor.navReceipts,
      'analytics' => TutorialAnchor.navAnalytics,
      _ => null,
    };
    if (anchor == null) return child;
    return TutorialTarget(anchor: anchor, child: child);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.slate900 : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: selected ? Colors.white : AppColors.slate500),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : AppColors.slate600,
                  ),
                ),
              ),
              if (badge != null && badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.restaurant : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
