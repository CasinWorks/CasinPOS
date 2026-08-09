import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/enums.dart';

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
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Invite teammate'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'They must sign up/sign in with this exact email, then paste the token.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
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
                    onChanged: (v) {
                      if (v != null) setLocal(() => role = v);
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  if (token != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    SelectableText(
                      token!,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: token!));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Token copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy token'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(token == null ? 'Cancel' : 'Done'),
              ),
              if (token == null)
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setLocal(() {
                            loading = true;
                            error = null;
                          });
                          try {
                            final row = await ref
                                .read(storeRepositoryProvider)
                                .createInvitation(
                                  storeId: membership.storeId,
                                  email: emailCtrl.text,
                                  role: role,
                                );
                            setLocal(() => token = row['token'] as String?);
                          } catch (e) {
                            setLocal(() => error = e.toString());
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
                      : const Text('Create invite'),
                ),
            ],
          );
        },
      );
    },
  );

  emailCtrl.dispose();
}
