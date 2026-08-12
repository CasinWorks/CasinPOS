import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/connectivity_providers.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../data/providers/sync_providers.dart';
import '../settings/store_settings_dialog.dart';
import '../team/team_manage_dialog.dart';

/// Account / Sign out sheet for phone layout (sidebar is hidden).
Future<void> showMobileAccountSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _MobileAccountSheet(),
  );
}

class _MobileAccountSheet extends ConsumerWidget {
  const _MobileAccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    final storeName = membership?.store.name ?? 'My Store';
    final role = membership?.role.value ?? 'staff';
    final online = ref.watch(connectivityOnlineProvider).valueOrNull ?? true;
    final pendingSync = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    String userName = 'Team member';
    try {
      final user = ref.watch(authRepositoryProvider).currentUser;
      userName = (user?.userMetadata?['full_name'] as String?) ??
          user?.email ??
          'Team member';
    } catch (_) {}

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Store settings'),
              onTap: () {
                Navigator.pop(context);
                showStoreSettingsDialog(context, ref);
              },
            ),
            if (membership?.role.canInviteUsers == true)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_offer_outlined),
                title: const Text('Promos / discount codes'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(retailTabProvider.notifier).state = 'promos';
                },
              ),
            if (membership?.role.canInviteUsers == true)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.group_outlined),
                title: const Text('Invite / Manage team'),
                onTap: () {
                  Navigator.pop(context);
                  showTeamManageDialog(context, ref);
                },
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
                if (context.mounted) context.go('/login');
              },
            ),
          ],
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
