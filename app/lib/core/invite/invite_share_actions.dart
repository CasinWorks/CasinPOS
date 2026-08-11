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

  @override
  Widget build(BuildContext context) {
    final link = AppUrl.inviteLink(token);

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
        const Text(
          'What they do',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          '1. Open the join link (from email or from you)\n'
          '2. Create an account / sign in as $email\n'
          '3. They’re in — no token paste needed',
          style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.slate600),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
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
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  link,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ),
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
