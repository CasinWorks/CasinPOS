import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/display/open_customer_display.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/platform_providers.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/enums.dart';
import '../../../domain/permissions.dart';
import '../billing/upgrade_premium_dialog.dart';
import '../franchise/franchise_dialog.dart';
import '../onboarding/story_mode.dart';
import '../settings/store_settings_dialog.dart';
import '../team/team_manage_dialog.dart';

/// Phone “More” hub — every desktop sidebar destination that isn’t in the
/// bottom nav (POS / Stock / Sales / Receipts).
class MobileMoreView extends ConsumerWidget {
  const MobileMoreView({super.key});

  void _go(WidgetRef ref, String tab) {
    ref.read(retailTabProvider.notifier).state = tab;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    final isPlatformAdmin =
        ref.watch(isPlatformAdminProvider).valueOrNull ?? false;
    final storeName = membership?.store.name ?? 'My Store';
    final plan = membership?.store.planTier;
    final role = membership?.role;

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.slate400,
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'More',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          storeName,
          style: const TextStyle(fontSize: 13, color: AppColors.slate500),
        ),
        if (plan == PlanTier.free && role?.canManageBilling == true) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => showUpgradePremiumDialog(
              context,
              reason: UpgradeReason.general,
              storeName: storeName,
              storeId: membership?.storeId,
            ),
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: const Text('Upgrade to Premium'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandYellow,
              foregroundColor: AppColors.ink,
            ),
          ),
        ],
        section('OPERATIONS'),
        _MoreTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Cash Register',
          subtitle: 'Open / close till shifts',
          onTap: () => _go(ref, 'register'),
        ),
        if (role?.canInviteUsers == true)
          _MoreTile(
            icon: Icons.local_offer_outlined,
            title: 'Promos / Codes',
            subtitle: 'Discount codes',
            onTap: () => _go(ref, 'promos'),
          ),
        if (membership != null && Permissions.canViewReports(membership.role))
          _MoreTile(
            icon: Icons.assessment_outlined,
            title: 'Reports',
            subtitle: 'Sales & inventory reports',
            onTap: () => _go(ref, 'reports'),
          ),
        _MoreTile(
          icon: Icons.trending_up,
          title: 'Sales Statistics',
          subtitle: 'Charts and trends',
          onTap: () => _go(ref, 'analytics'),
        ),
        section('STORE'),
        _MoreTile(
          icon: Icons.settings_outlined,
          title: 'Store Settings',
          subtitle: 'Name, payments, legal',
          onTap: () => showStoreSettingsDialog(context, ref),
        ),
        if (role?.canInviteUsers == true)
          _MoreTile(
            icon: Icons.group_outlined,
            title: 'Invite / Manage team',
            subtitle: 'Seats, roles, PINs',
            onTap: () => showTeamManageDialog(context, ref),
          ),
        if (membership != null &&
            Permissions.canOpenFranchise(
              membership.role,
              storeIsFranchise: membership.store.isFranchise,
            ))
          _MoreTile(
            icon: Icons.storefront_outlined,
            title: 'Franchise',
            subtitle: 'Linked stores',
            onTap: () => showFranchiseDialog(context, ref),
          ),
        _MoreTile(
          icon: Icons.tv_outlined,
          title: 'Customer Display',
          subtitle: 'Second-screen cart',
          onTap: () async {
            final ok = await openCustomerDisplayWindow();
            if (!context.mounted) return;
            if (!ok) {
              showAppMessage(
                context,
                'Could not open customer display',
                isError: true,
              );
            }
          },
        ),
        _MoreTile(
          icon: Icons.auto_awesome,
          title: 'Replay tutorial',
          subtitle: 'Story walkthrough',
          onTap: () => startRetailStory(ref),
        ),
        section('HELP'),
        _MoreTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          onTap: () => _go(ref, 'notifications'),
        ),
        _MoreTile(
          icon: Icons.help_outline_rounded,
          title: 'Support',
          onTap: () => _go(ref, 'support'),
        ),
        if (isPlatformAdmin) ...[
          section('CASINWORKS'),
          _MoreTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Platform Ops',
            subtitle: 'All tenants, plans, support tools',
            emphasize: true,
            onTap: () => _go(ref, 'ops'),
          ),
        ],
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.emphasize = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: emphasize ? const Color(0xFFFFF8E1) : AppColors.slate100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: emphasize ? AppColors.brandYellow : AppColors.slate200,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: emphasize ? AppColors.ink : AppColors.slate600,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppColors.ink,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.slate400),
        onTap: onTap,
      ),
    );
  }
}
