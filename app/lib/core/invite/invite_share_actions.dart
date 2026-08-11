import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_url.dart';
import '../errors/app_errors.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'open_external_uri.dart';

/// Actions shown after an invite token is created (email status + share backups).
class InviteShareActions extends StatelessWidget {
  const InviteShareActions({
    super.key,
    required this.email,
    required this.token,
    this.storeName,
    this.emailed,
    this.emailNote,
  });

  final String email;
  final String token;
  final String? storeName;

  /// `true` emailed, `false` not emailed, `null` unknown / not attempted.
  final bool? emailed;
  final String? emailNote;

  String get _link => AppUrl.inviteLink(token);

  String get _instructionsText {
    final store = (storeName == null || storeName!.trim().isEmpty)
        ? 'the store'
        : storeName!.trim();
    return 'Join $store on CasinPOS\n\n'
        '1. Open this link:\n$_link\n\n'
        '2. Create an account or sign in using exactly:\n$email\n\n'
        '3. You’re in — no token paste needed.\n';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (emailed == true)
          Text(
            'We emailed $email a join link.',
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          )
        else if (emailed == false)
          Text(
            _cleanEmailNote(emailNote, email),
            style: const TextStyle(color: AppColors.slate600, fontSize: 13),
          ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell them to do this',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Open the join link below\n'
                '2. Create an account or sign in as\n   $email\n'
                '3. Done — CasinPOS joins them automatically',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Join link',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _link,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _link));
            if (context.mounted) {
              showAppMessage(context, 'Join link copied');
            }
          },
          icon: const Icon(Icons.link, size: 18),
          label: const Text('Copy join link'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _instructionsText));
            if (context.mounted) {
              showAppMessage(context, 'Instructions + link copied');
            }
          },
          icon: const Icon(Icons.checklist_rtl, size: 18),
          label: const Text('Copy instructions'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () async {
            final mailto = AppUrl.inviteMailto(
              toEmail: email,
              token: token,
              storeName: storeName,
            );
            final opened = await openExternalUri(mailto);
            if (!opened && context.mounted) {
              await Clipboard.setData(ClipboardData(text: mailto.toString()));
              if (context.mounted) {
                showAppMessage(
                  context,
                  'Email draft copied — paste into your mail app',
                );
              }
            }
          },
          icon: const Icon(Icons.mail_outline, size: 18),
          label: const Text('Open email draft'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              'Advanced',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Only if the join link fails',
              style: TextStyle(fontSize: 11, color: AppColors.slate500),
            ),
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: token));
                  if (context.mounted) {
                    showAppMessage(
                      context,
                      'Token copied — they paste it on Join your team',
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy backup token'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _cleanEmailNote(String? emailNote, String email) {
  const fallback =
      'Email wasn’t sent. Copy the join link and send it yourself.';
  final raw = (emailNote ?? '').trim();
  if (raw.isEmpty) return '$fallback ($email)';
  if (raw.contains('minified:') ||
      raw.contains('status: 502') ||
      raw.contains('FunctionException') ||
      raw.contains('details:') ||
      raw.contains('RESEND_FAILED') ||
      raw.length > 160) {
    return '$fallback ($email)';
  }
  return raw;
}
