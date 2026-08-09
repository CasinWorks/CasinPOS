import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_url.dart';
import '../../core/errors/app_errors.dart';
import '../../core/invite/invite_share_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers/session_providers.dart';
import '../../domain/enums.dart';

Future<void> showInviteTeammateDialog(BuildContext context, WidgetRef ref) async {
  final membership = ref.read(activeMembershipProvider);
  if (membership == null || !membership.role.canInviteUsers) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Only Owner or Admin can invite teammates.')),
    );
    return;
  }

  final emailCtrl = TextEditingController();
  var role = StoreRole.staff;
  String? error;
  String? token;
  String? invitedEmail;
  bool? emailed;
  String? emailNote;
  var resent = false;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Invite teammate'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    token == null
                        ? 'We’ll email them a join link. They must create/sign in with this exact email.'
                        : resent
                            ? 'Invite already pending — we resent the email. Share the link if they still don’t see it.'
                            : 'Share the link if they didn’t get email. They open it → sign up with the invited email → done.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (token == null) ...[
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !loading,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<StoreRole>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        for (final r in [
                          if (membership.role == StoreRole.owner) StoreRole.admin,
                          StoreRole.manager,
                          StoreRole.staff,
                        ])
                          DropdownMenuItem(value: r, child: Text(r.value)),
                      ],
                      onChanged: loading
                          ? null
                          : (v) {
                              if (v != null) setLocal(() => role = v);
                            },
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  if (token != null && invitedEmail != null) ...[
                    InviteShareActions(
                      email: invitedEmail!,
                      token: token!,
                      storeName: membership.store.name,
                      emailed: emailed,
                      emailNote: emailNote,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: Text(token == null ? 'Cancel' : 'Done'),
              ),
              if (token == null)
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim().toLowerCase();
                          if (!email.contains('@')) {
                            setLocal(() => error = 'Enter a valid email');
                            return;
                          }
                          setLocal(() {
                            loading = true;
                            error = null;
                          });
                          try {
                            final row = await ref
                                .read(storeRepositoryProvider)
                                .createInvitation(
                                  storeId: membership.storeId,
                                  email: email,
                                  role: role,
                                );
                            final t = row['token'] as String?;
                            final wasResent = row['resent'] == true;
                            if (t == null || t.isEmpty) {
                              setLocal(() => error = 'Invite created but token missing');
                              return;
                            }
                            final link = AppUrl.inviteLink(t);
                            final inviter =
                                ref.read(authRepositoryProvider).currentUser;
                            final fullName =
                                (inviter?.userMetadata?['full_name'] as String?)
                                    ?.trim();
                            final inviterName =
                                (fullName != null && fullName.isNotEmpty)
                                    ? fullName
                                    : inviter?.email;
                            final mail = await ref
                                .read(storeRepositoryProvider)
                                .sendInviteEmail(
                                  email: email,
                                  token: t,
                                  storeName: membership.store.name,
                                  role: role.value,
                                  inviteUrl: link,
                                  inviterName: inviterName,
                                );
                            setLocal(() {
                              token = t;
                              invitedEmail = email;
                              resent = wasResent;
                              emailed = mail.emailed;
                              emailNote = mail.emailed
                                  ? null
                                  : (mail.message ??
                                      'Configure RESEND_API_KEY on Supabase to auto-email invites.');
                            });
                            if (ctx.mounted && wasResent) {
                              showAppMessage(
                                ctx,
                                mail.emailed
                                    ? 'Invite already pending — we resent the email'
                                    : 'Invite already pending — use the copy link below',
                              );
                            }
                          } catch (e) {
                            setLocal(
                              () => error = friendlyError(
                                e,
                                fallback: 'Could not send invite. Please try again.',
                              ),
                            );
                          } finally {
                            setLocal(() => loading = false);
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send invite'),
                ),
            ],
          );
        },
      );
    },
  );

  emailCtrl.dispose();
}
