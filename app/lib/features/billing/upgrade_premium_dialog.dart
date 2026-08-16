import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/support_contact.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum UpgradeReason {
  teamSeats,
  monthlyTransactions,
  general,
}

/// Contact-support upgrade flow until Stripe/PayMongo self-serve is wired.
/// Platform Ops still flips Free ↔ Premium manually.
Future<void> showUpgradePremiumDialog(
  BuildContext context, {
  UpgradeReason reason = UpgradeReason.general,
  String? storeName,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _UpgradePremiumDialog(
      reason: reason,
      storeName: storeName,
    ),
  );
}

class _UpgradePremiumDialog extends StatelessWidget {
  const _UpgradePremiumDialog({
    required this.reason,
    this.storeName,
  });

  final UpgradeReason reason;
  final String? storeName;

  static const _supportEmail = SupportContact.email;

  String get _headline => switch (reason) {
        UpgradeReason.teamSeats => 'Need more team seats?',
        UpgradeReason.monthlyTransactions => 'Monthly sales limit reached',
        UpgradeReason.general => 'Upgrade to Premium',
      };

  String get _body => switch (reason) {
        UpgradeReason.teamSeats =>
          'Free includes you + 1 teammate. Premium unlocks more staff seats. '
              'Send a request and CasinPOS will flip your plan in Platform Ops.',
        UpgradeReason.monthlyTransactions =>
          'Free includes 1,000 paid sales per month. Premium removes that cap. '
              'Send a request and CasinPOS will upgrade your store.',
        UpgradeReason.general =>
          'Premium unlocks more seats, higher monthly sales limit, and franchise tools. '
              'Self-serve checkout is coming — until then, email us and we’ll activate Premium.',
      };

  Uri get _mailto {
    final store = (storeName == null || storeName!.trim().isEmpty)
        ? 'my store'
        : storeName!.trim();
    final subject = 'CasinPOS Premium upgrade — $store';
    final body = 'Hi CasinPOS team,\n\n'
        'Please upgrade this store to Premium:\n'
        'Store: $store\n'
        'Reason: ${_reasonLabel(reason)}\n\n'
        'Thanks,\n';
    return Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
  }

  String _reasonLabel(UpgradeReason r) => switch (r) {
        UpgradeReason.teamSeats => 'Need more team seats',
        UpgradeReason.monthlyTransactions => 'Hit monthly transaction limit',
        UpgradeReason.general => 'General Premium upgrade',
      };

  Future<void> _email(BuildContext context) async {
    final uri = _mailto;
    final ok = await launchUrl(uri);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app — copy the address instead.')),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    final text =
        '$_supportEmail\nSubject: CasinPOS Premium upgrade — ${storeName ?? 'my store'}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support email copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_headline),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What you get on Premium',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('· More than 2 team seats', style: Theme.of(context).textTheme.bodySmall),
                  Text('· Higher monthly sales allowance', style: Theme.of(context).textTheme.bodySmall),
                  Text('· Franchise & multi-store tools', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Email $_supportEmail — we’ll activate Premium manually until in-app billing ships.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
        TextButton(onPressed: () => _copy(context), child: const Text('Copy email')),
        FilledButton(
          onPressed: () => _email(context),
          child: const Text('Request upgrade'),
        ),
      ],
    );
  }
}
