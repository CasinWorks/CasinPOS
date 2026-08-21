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
          const SizedBox(height: 16),
          const Text(
            'Delete account',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const _DeleteAccountCard(),
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

class _DeleteAccountCard extends ConsumerStatefulWidget {
  const _DeleteAccountCard();

  @override
  ConsumerState<_DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends ConsumerState<_DeleteAccountCard> {
  var _busy = false;

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (c2) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This cannot be undone. Your login will be deleted. '
          'If you are the only owner of a store, that store and its data will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c2, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c2, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(storeRepositoryProvider).deleteAccount();
      if (!mounted) return;
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppMessage(
        context,
        friendlyError(e, fallback: 'Could not delete account'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Permanently delete your CasinPOS account and sign out. '
            'Stores you solely own will be removed.',
            style: TextStyle(fontSize: 13, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _deleteAccount,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
            label: Text(
              _busy ? 'Deleting…' : 'Delete my account',
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
