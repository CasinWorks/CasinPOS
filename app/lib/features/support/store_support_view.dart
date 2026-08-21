import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/support_contact.dart';
import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers/session_providers.dart';
import '../billing/upgrade_premium_dialog.dart';

/// In-app Support — real contact path for App Review (no “coming soon”).
class StoreSupportView extends ConsumerWidget {
  const StoreSupportView({super.key});

  Future<void> _email(
    BuildContext context, {
    required String subject,
    String? body,
  }) async {
    final uri = SupportContact.mailto(subject: subject, body: body);
    final ok = await launchUrl(uri);
    if (!context.mounted) return;
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: SupportContact.email));
      if (!context.mounted) return;
      showAppMessage(context, 'Could not open mail — address copied');
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: SupportContact.email));
    if (!context.mounted) return;
    showAppMessage(context, 'Support email copied');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    final storeName = membership?.store.name ?? 'my store';
    final storeId = membership?.storeId;
    final userEmail = ref.watch(authRepositoryProvider).currentUser?.email;

    final defaultBody = StringBuffer()
      ..writeln('Hi CasinPOS Support,')
      ..writeln()
      ..writeln('Store: $storeName')
      ..writeln(storeId != null ? 'Store ID: $storeId' : '')
      ..writeln(userEmail != null ? 'My login: $userEmail' : '')
      ..writeln()
      ..writeln('How can you help:')
      ..writeln()
      ..writeln('Thanks,');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text(
            'Support',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'We’re here to help with your store, team, billing, and account.',
            style: TextStyle(fontSize: 13, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Email us',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  SupportContact.email,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Usually reply within 1–2 business days.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _email(
                    context,
                    subject: 'CasinPOS support — $storeName',
                    body: defaultBody.toString(),
                  ),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text('Open email draft'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copyEmail(context),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy email address'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Common requests',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _SupportTopic(
            title: 'Premium / billing',
            subtitle: 'Subscribe or restore in the iOS / Android app',
            onTap: () {
              final canBill =
                  membership?.role.canManageBilling == true;
              if (!canBill) {
                showAppMessage(
                  context,
                  'Only the store Owner can manage Premium billing.',
                  isError: true,
                );
                return;
              }
              showUpgradePremiumDialog(
                context,
                reason: UpgradeReason.general,
                storeName: storeName,
                storeId: storeId,
              );
            },
          ),
          _SupportTopic(
            title: 'Team / invite help',
            subtitle: 'Invite link, roles, or can’t join',
            onTap: () => _email(
              context,
              subject: 'CasinPOS team invite help — $storeName',
              body: defaultBody.toString(),
            ),
          ),
          _SupportTopic(
            title: 'Account deletion',
            subtitle: 'Or use Store settings → Delete my account',
            onTap: () => _email(
              context,
              subject: 'CasinPOS account deletion request',
              body: 'Hi CasinPOS Support,\n\n'
                  'Please delete my CasinPOS account.\n'
                  '${userEmail != null ? 'Login email: $userEmail\n' : ''}'
                  '${storeId != null ? 'Store ID: $storeId\n' : ''}\n'
                  'Thanks,\n',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Policies',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Use', style: TextStyle(fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/terms'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'CasinWorks · ${SupportContact.displayName}',
            style: const TextStyle(fontSize: 11, color: AppColors.slate400),
          ),
        ],
      ),
    );
  }
}

class _SupportTopic extends StatelessWidget {
  const _SupportTopic({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.mail_outline, size: 18, color: AppColors.slate500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
