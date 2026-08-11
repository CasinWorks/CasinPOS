import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_url.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_errors.dart';
import '../../core/invite/invite_share_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers/session_providers.dart';
import '../../domain/enums.dart';
import '../billing/upgrade_premium_dialog.dart';

/// Opens invite UI. Uses its own [ConsumerStatefulWidget] so parent `ref`
/// is never used after Team Manage (or other callers) pop/dispose.
Future<void> showInviteTeammateDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _InviteTeammateDialog(),
  );
}

class _InviteTeammateDialog extends ConsumerStatefulWidget {
  const _InviteTeammateDialog();

  @override
  ConsumerState<_InviteTeammateDialog> createState() =>
      _InviteTeammateDialogState();
}

class _InviteTeammateDialogState extends ConsumerState<_InviteTeammateDialog> {
  final _emailCtrl = TextEditingController();
  StoreRole _role = StoreRole.staff;
  String? _error;
  String? _token;
  String? _invitedEmail;
  bool? _emailed;
  String? _emailNote;
  var _resent = false;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _guardSeats());
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardSeats() async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!membership.role.canInviteUsers) {
      if (!mounted) return;
      showAppMessage(
        context,
        'Only Owner or Admin can invite teammates.',
        isError: true,
      );
      Navigator.pop(context);
      return;
    }
    if (membership.store.planTier != PlanTier.free) return;
    try {
      final seats = await ref
          .read(storeRepositoryProvider)
          .storeSeatUsage(membership.storeId);
      if (!mounted) return;
      if (seats.seatsUsed >= AppConstants.freeTeamSeatLimit) {
        await showUpgradePremiumDialog(
          context,
          reason: UpgradeReason.teamSeats,
          storeName: membership.store.name,
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      // RPC invite still enforces.
    }
  }

  Future<void> _send() async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null) return;

    final email = _emailCtrl.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final row = await ref.read(storeRepositoryProvider).createInvitation(
            storeId: membership.storeId,
            email: email,
            role: _role,
          );
      if (!mounted) return;

      final t = row['token'] as String?;
      final wasResent = row['resent'] == true;
      if (t == null || t.isEmpty) {
        setState(() => _error = 'Invite created but link missing — try again');
        return;
      }

      final link = AppUrl.inviteLink(t);
      final inviter = ref.read(authRepositoryProvider).currentUser;
      final fullName =
          (inviter?.userMetadata?['full_name'] as String?)?.trim();
      final inviterName =
          (fullName != null && fullName.isNotEmpty) ? fullName : inviter?.email;

      final mail = await ref.read(storeRepositoryProvider).sendInviteEmail(
            email: email,
            token: t,
            storeName: membership.store.name,
            role: _role.value,
            inviteUrl: link,
            inviterName: inviterName,
          );
      if (!mounted) return;

      setState(() {
        _token = t;
        _invitedEmail = email;
        _resent = wasResent;
        _emailed = mail.emailed;
        _emailNote = mail.emailed
            ? null
            : (mail.message ??
                'We couldn’t email them automatically. Copy the join link and send it yourself.');
      });
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(
        e,
        fallback: 'Could not send invite. Please try again.',
      );
      if (msg.toLowerCase().contains('upgrade to premium') ||
          msg.toUpperCase().contains('FREE_TEAM_SEAT_LIMIT')) {
        await showUpgradePremiumDialog(
          context,
          reason: UpgradeReason.teamSeats,
          storeName: membership.store.name,
        );
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(activeMembershipProvider);
    if (membership == null) {
      return AlertDialog(
        title: const Text('Invite teammate'),
        content: const Text('No active store.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
    }

    final token = _token;
    final invitedEmail = _invitedEmail;

    return AlertDialog(
      title: Text(token == null ? 'Invite teammate' : 'Share join link'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              token == null
                  ? membership.store.planTier == PlanTier.free
                      ? 'Free plan: you + 1 teammate. Enter their email — we’ll try to email a join link.'
                      : 'Enter their email. They must sign up / sign in with that same email.'
                  : 'Send them the join link below. One link is enough — they don’t need a separate token.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (token == null) ...[
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Their email'),
                keyboardType: TextInputType.emailAddress,
                enabled: !_loading,
                autofocus: true,
                onSubmitted: (_) {
                  if (!_loading) _send();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<StoreRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in [
                    if (membership.role == StoreRole.owner) StoreRole.admin,
                    StoreRole.manager,
                    StoreRole.staff,
                  ])
                    DropdownMenuItem(value: r, child: Text(r.value)),
                ],
                onChanged: _loading
                    ? null
                    : (v) {
                        if (v != null) setState(() => _role = v);
                      },
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            if (token != null && invitedEmail != null) ...[
              if (_resent) ...[
                Text(
                  _emailed == true
                      ? 'This invite was already pending — we resent the email.'
                      : 'This invite was already pending. Share the join link below.',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate600),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              InviteShareActions(
                email: invitedEmail,
                token: token,
                storeName: membership.store.name,
                emailed: _emailed,
                emailNote: _emailNote,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(token == null ? 'Cancel' : 'Done'),
        ),
        if (token == null)
          FilledButton(
            onPressed: _loading ? null : _send,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create join link'),
          ),
      ],
    );
  }
}
