import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/support_contact.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/powered_by_casinworks.dart';
import '../../domain/enums.dart';

/// Public legal document pages for App Store / Play Console.
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.updatedLabel,
    required this.sections,
  });

  final String title;
  final String updatedLabel;
  final List<({String heading, String body})> sections;

  String plainText() {
    final lines = <String>[title, updatedLabel, ''];
    for (final s in sections) {
      lines.add(s.heading);
      lines.add(s.body);
      lines.add('');
    }
    return lines.join('\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: plainText()));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        children: [
          const BrandLogo(size: 56, radius: 14),
          const SizedBox(height: 12),
          const BrandMark(businessType: BusinessType.retail),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          SelectableText(
            updatedLabel,
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 20),
          for (final s in sections) ...[
            SelectableText(
              s.heading,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 8),
            SelectableText(
              s.body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.slate700,
              ),
            ),
            const SizedBox(height: 18),
          ],
          const PoweredByCasinworks(),
        ],
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      title: 'Privacy Policy',
      updatedLabel: 'Last updated: September 14, 2026',
      sections: const [
        (
          heading: 'Who we are',
          body:
              'CasinPOS is operated by CasinWorks. This policy explains how we collect, use, and store information when you use CasinPOS on web or tablet.',
        ),
        (
          heading: 'Information we collect',
          body:
              'Account data (name, email), store profile (store name, payment preferences, optional business TIN/address), product catalog and inventory, sales transactions, cash register sessions, and basic device/app diagnostics needed to run the service.',
        ),
        (
          heading: 'How we use information',
          body:
              'We use this data to provide POS features (selling, inventory, receipts, analytics, team invites), secure your account, prevent abuse, improve reliability, and communicate service-related notices.',
        ),
        (
          heading: 'Sharing',
          body:
              'We do not sell your personal data. We use infrastructure providers (such as Supabase for auth/database and hosting for the web app) solely to operate CasinPOS. Team members you invite can see store operational data according to their role.',
        ),
        (
          heading: 'Retention',
          body:
              'We keep account and store data while your account is active. You may request account deletion in the app. After deletion, we remove or anonymize personal data except records we must retain for legal, security, or fraud prevention purposes.',
        ),
        (
          heading: 'Your choices',
          body:
              'You can update store settings, invite/remove teammates (if permitted), export receipts/PDF reports, and delete your account from Support → Delete my account.',
        ),
        (
          heading: 'Contact',
          body:
              'Questions about privacy: ${SupportContact.email}.',
        ),
      ],
    );
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      title: 'Terms of Use',
      updatedLabel: 'Last updated: September 14, 2026',
      sections: const [
        (
          heading: 'Agreement',
          body:
              'By creating a CasinPOS account or using the app, you agree to these Terms of Use (EULA). If you use CasinPOS for a business, you confirm you have authority to bind that business.',
        ),
        (
          heading: 'The service',
          body:
              'CasinPOS provides point-of-sale, inventory, receipts, and related tools for retail tablet/web use. Features may change as we improve the product. Free plans may include usage limits.',
        ),
        (
          heading: 'Paid app access',
          body:
              'CasinPOS on Apple is a paid application. The App Store price (typically ₱199 in the Philippines) is charged once when you purchase the app. '
              'After purchase and install, creating a store unlocks full Premium features (team seats, higher sales limits, franchise tools, and related features). '
              'There is no separate in-app subscription and no auto-renewing In-App Purchase. '
              'Platform operators may adjust a store’s plan for support or abuse prevention.',
        ),
        (
          heading: 'Your responsibilities',
          body:
              'You are responsible for account security, staff access, accurate catalog/pricing/tax settings, complying with local laws (including Philippine tax and receipt rules where applicable), and verifying sales totals before charging customers.',
        ),
        (
          heading: 'Offline use',
          body:
              'CasinPOS may allow offline selling on a device and sync later. You are responsible for reconciling offline sales, avoiding duplicate sync conflicts, and verifying stock after reconnecting.',
        ),
        (
          heading: 'Acceptable use',
          body:
              'Do not misuse CasinPOS, attempt unauthorized access, disrupt service, or use it for unlawful activity.',
        ),
        (
          heading: 'Disclaimer',
          body:
              'CasinPOS is provided “as is.” We do not guarantee uninterrupted service. To the fullest extent allowed by law, CasinWorks is not liable for lost profits, inventory discrepancies, or tax assessment outcomes arising from your configuration or use of the app.',
        ),
        (
          heading: 'Termination',
          body:
              'You may delete your account at any time. We may suspend accounts that violate these Terms or threaten service integrity.',
        ),
        (
          heading: 'Contact',
          body: 'Questions: ${SupportContact.email}',
        ),
      ],
    );
  }
}
