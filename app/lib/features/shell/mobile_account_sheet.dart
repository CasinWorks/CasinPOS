import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/connectivity_providers.dart';
import '../../../data/providers/platform_providers.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../data/providers/sync_providers.dart';
import '../../../domain/enums.dart';
import '../../../domain/permissions.dart';
import '../billing/upgrade_premium_dialog.dart';
import '../franchise/franchise_dialog.dart';
import '../settings/store_settings_dialog.dart';
import '../team/team_manage_dialog.dart';

/// Account / Sign out sheet for phone layout (sidebar is hidden).
Future<void> showMobileAccountSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _MobileAccountSheet(hostContext: context),
  );
}

class _MobileAccountSheet extends ConsumerWidget {
  const _MobileAccountSheet({required this.hostContext});

  /// Parent context (shell) — safe after this sheet is popped.
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    final memberships = ref.watch(membershipsProvider).valueOrNull ?? const [];
    final storeName = membership?.store.name ?? 'My Store';
    final role = membership?.role.value ?? 'staff';
    final online = ref.watch(connectivityOnlineProvider).valueOrNull ?? true;
    final pendingSync = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final isPlatformAdmin =
        ref.watch(isPlatformAdminProvider).valueOrNull ?? false;

    String userName = 'Team member';
    try {
      final user = ref.watch(authRepositoryProvider).currentUser;
      userName = (user?.userMetadata?['full_name'] as String?) ??
          user?.email ??
          'Team member';
    } catch (_) {}

    void openAfterClose(VoidCallback action) {
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hostContext.mounted) action();
      });
    }

    void goTab(String tab) => openAfterClose(() {
          ref.read(retailTabProvider.notifier).state = tab;
        });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.slate200,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$storeName · $role',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                online
                    ? (pendingSync > 0
                        ? 'Online · $pendingSync waiting to sync'
                        : 'Online · synced')
                    : 'Offline · sales will sync later',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: online ? AppColors.success : AppColors.slate500,
                ),
              ),
              if (memberships.length > 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: membership?.storeId,
                  decoration: const InputDecoration(
                    labelText: 'Active store',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in memberships)
                      DropdownMenuItem(
                        value: m.storeId,
                        child: Text(m.store.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) async {
                    if (id == null) return;
                    Navigator.pop(context);
                    await ref.read(preferredStoreIdProvider.notifier).select(id);
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (membership?.store.planTier == PlanTier.free &&
                  membership?.role.canManageBilling == true) ...[
                FilledButton.icon(
                  onPressed: () => openAfterClose(
                    () => showUpgradePremiumDialog(
                      hostContext,
                      reason: UpgradeReason.general,
                      storeName: storeName,
                      storeId: membership?.storeId,
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: const Text('Upgrade to Premium'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandYellow,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Store settings'),
                onTap: () => openAfterClose(
                  () => showStoreSettingsDialog(hostContext, ref),
                ),
              ),
              if (membership?.role.canInviteUsers == true)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('Invite / Manage team'),
                  onTap: () => openAfterClose(
                    () => showTeamManageDialog(hostContext, ref),
                  ),
                ),
              if (membership != null &&
                  Permissions.canOpenFranchise(
                    membership.role,
                    storeIsFranchise: membership.store.isFranchise,
                  ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Franchise'),
                  onTap: () => openAfterClose(
                    () => showFranchiseDialog(hostContext, ref),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Cash Register'),
                onTap: () => goTab('register'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.trending_up),
                title: const Text('Sales Statistics'),
                onTap: () => goTab('analytics'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('Notifications'),
                onTap: () => goTab('notifications'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('Support'),
                onTap: () => goTab('support'),
              ),
              if (isPlatformAdmin)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text(
                    'Platform Ops',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('All tenants & billing tools'),
                  onTap: () => goTab('ops'),
                ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text(
                  'Sign out',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref.read(authRepositoryProvider).signOut();
                  } catch (_) {}
                  if (hostContext.mounted) hostContext.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact account control for the phone top bar.
class MobileAccountButton extends ConsumerWidget {
  const MobileAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Account',
      onPressed: () => showMobileAccountSheet(context, ref),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.slate100,
        foregroundColor: AppColors.slate800,
      ),
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}
