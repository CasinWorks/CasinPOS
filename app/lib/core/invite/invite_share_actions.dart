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
            'Invite email sent to $email.',
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          )
        else if (emailed == false)
          Text(
            emailNote ??
                'Email wasn’t sent automatically. Use Copy invite link or Open email draft below.',
            style: const TextStyle(color: AppColors.slate600, fontSize: 13),
          ),
        const SizedBox(height: AppSpacing.sm),
        SelectableText(
          link,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) {
                  showAppMessage(context, 'Invite link copied');
                }
              },
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Copy invite link'),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: token));
                if (context.mounted) {
                  showAppMessage(context, 'Invite token copied');
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy token'),
            ),
            TextButton.icon(
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
                      'Mailto copied — paste into your browser address bar',
                    );
                  }
                }
              },
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('Open email draft'),
            ),
          ],
        ),
      ],
    );
  }
}
