import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_url.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_errors.dart';
import '../../core/invite/invite_share_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/store_models.dart';
import '../../data/providers/session_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/enums.dart';
import '../billing/upgrade_premium_dialog.dart';

/// Opens invite UI without holding a [WidgetRef] across async gaps.
Future<void> showInviteTeammateDialog(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final membership = container.read(activeMembershipProvider);
  if (membership == null) {
    if (context.mounted) {
      showAppMessage(context, 'No active store.', isError: true);
    }
    return;
  }
  if (!membership.role.canInviteUsers) {
    if (context.mounted) {
      showAppMessage(
        context,
        'Only Owner or Admin can invite teammates.',
        isError: true,
      );
    }
    return;
  }

  final storeRepo = container.read(storeRepositoryProvider);
  final authRepo = container.read(authRepositoryProvider);

  if (membership.store.planTier == PlanTier.free) {
    try {
      final seats = await storeRepo.storeSeatUsage(membership.storeId);
      if (!context.mounted) return;
      if (seats.seatsUsed >= AppConstants.freeTeamSeatLimit) {
        await showUpgradePremiumDialog(
          context,
          reason: UpgradeReason.teamSeats,
          storeName: membership.store.name,
        );
        return;
      }
    } catch (_) {
      // RPC invite still enforces.
    }
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _InviteTeammateDialog(
      membership: membership,
      storeRepo: storeRepo,
      authRepo: authRepo,
    ),
  );
}

class _InviteTeammateDialog extends StatefulWidget {
  const _InviteTeammateDialog({
    required this.membership,
    required this.storeRepo,
    required this.authRepo,
  });

  final StoreMembership membership;
  final StoreRepository storeRepo;
  final AuthRepository authRepo;

  @override
  State<_InviteTeammateDialog> createState() => _InviteTeammateDialogState();
}

class _InviteTeammateDialogState extends State<_InviteTeammateDialog> {
  final _emailCtrl = TextEditingController();
  late StoreRole _role = StoreRole.staff;
  String? _error;
  String? _token;
  String? _invitedEmail;
  bool? _emailed;
  String? _emailNote;
  var _resent = false;
  var _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Capture locals — never touch Riverpod `ref` in this widget.
    final storeId = widget.membership.storeId;
    final storeName = widget.membership.store.name;
    final role = _role;
    final storeRepo = widget.storeRepo;
    final authRepo = widget.authRepo;

    try {
      List<String>? branchIds;
      if (role == StoreRole.branchManager) {
        final branches = await storeRepo.listStoreBranches(storeId);
        if (!mounted) return;
        if (branches.isEmpty) {
          setState(() {
            _loading = false;
            _error = 'No branches found. Create a branch first.';
          });
          return;
        }
        // Default: all listed branches (Free = Main only).
        branchIds = branches.map((b) => b.id).toList();
      }
      final row = await storeRepo.createInvitation(
        storeId: storeId,
        email: email,
        role: role,
        branchIds: branchIds,
      );
      if (!mounted) return;

      final t = row['token'] as String?;
      final wasResent = row['resent'] == true;
      if (t == null || t.isEmpty) {
        setState(() => _error = 'Invite created but link missing — try again');
        return;
      }

      final link = AppUrl.inviteLink(t);
      final inviter = authRepo.currentUser;
      final fullName =
          (inviter?.userMetadata?['full_name'] as String?)?.trim();
      final inviterName =
          (fullName != null && fullName.isNotEmpty) ? fullName : inviter?.email;

      final mail = await storeRepo.sendInviteEmail(
        email: email,
        token: t,
        storeName: storeName,
        role: role.value,
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
      // Never show Riverpod dispose internals in the invite form.
      if (msg.toLowerCase().contains('ref') &&
          msg.toLowerCase().contains('disposed')) {
        setState(() => _error = 'Something went wrong. Close this and try Invite again.');
        return;
      }
      if (msg.toLowerCase().contains('upgrade to premium') ||
          msg.toUpperCase().contains('FREE_TEAM_SEAT_LIMIT')) {
        await showUpgradePremiumDialog(
          context,
          reason: UpgradeReason.teamSeats,
          storeName: widget.membership.store.name,
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
    final membership = widget.membership;
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
                key: ValueKey(_role),
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in [
                    if (membership.role == StoreRole.owner) StoreRole.admin,
                    StoreRole.manager,
                    StoreRole.branchManager,
                    StoreRole.staff,
                  ])
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: _loading
                    ? null
                    : (v) {
                        if (v != null) setState(() => _role = v);
                      },
              ),
              if (_role == StoreRole.branchManager) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Branch Manager needs at least one branch. On Free plan there is usually one Main branch — we’ll assign it automatically after invite if you leave this as Branch Manager.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                ),
              ],
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
