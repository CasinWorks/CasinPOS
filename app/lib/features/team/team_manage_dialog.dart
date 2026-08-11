import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_url.dart';
import '../../core/errors/app_errors.dart';
import '../../core/invite/invite_share_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/team_models.dart';
import '../../data/providers/session_providers.dart';
import '../../domain/enums.dart';
import '../billing/upgrade_premium_dialog.dart';
import '../auth/pin_pad.dart';
import 'invite_teammate_dialog.dart';

Future<void> showTeamManageDialog(BuildContext context, WidgetRef ref) async {
  final membership = ref.read(activeMembershipProvider);
  if (membership == null || !membership.role.canInviteUsers) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Only Owner or Admin can manage the team.')),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => _TeamManageDialog(
      storeId: membership.storeId,
      storeName: membership.store.name,
      actorRole: membership.role,
      planTier: membership.store.planTier,
    ),
  );
}

class _TeamManageDialog extends ConsumerStatefulWidget {
  const _TeamManageDialog({
    required this.storeId,
    required this.storeName,
    required this.actorRole,
    required this.planTier,
  });

  final String storeId;
  final String storeName;
  final StoreRole actorRole;
  final PlanTier planTier;

  @override
  ConsumerState<_TeamManageDialog> createState() => _TeamManageDialogState();
}

class _TeamManageDialogState extends ConsumerState<_TeamManageDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StoreTeamSnapshot? _team;
  var _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final team = await ref.read(storeRepositoryProvider).listStoreTeam(widget.storeId);
      if (!mounted) return;
      setState(() {
        _team = team;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e, fallback: 'Could not load team.');
      });
    }
  }

  List<StoreRole> _assignableRoles(TeamMemberRow member) {
    final roles = <StoreRole>[
      if (widget.actorRole == StoreRole.owner) StoreRole.admin,
      StoreRole.manager,
      StoreRole.staff,
    ];
    if (!roles.contains(member.role) && member.role != StoreRole.owner) {
      return [member.role, ...roles];
    }
    return roles;
  }

  bool _canEditMember(TeamMemberRow member) {
    if (member.isSelf || member.role == StoreRole.owner) return false;
    if (widget.actorRole == StoreRole.admin && member.role == StoreRole.admin) {
      return false;
    }
    return true;
  }

  Future<void> _changeRole(TeamMemberRow member, StoreRole role) async {
    if (role == member.role) return;
    setState(() => _busyId = member.id);
    try {
      await ref.read(storeRepositoryProvider).updateMemberRole(
            memberId: member.id,
            role: role,
          );
      await _load();
      if (mounted) showAppMessage(context, 'Role updated');
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _removeMember(TeamMemberRow member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove teammate?'),
        content: Text(
          '${member.displayName} will lose access to ${widget.storeName}. '
          'You can invite them again later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = member.id);
    try {
      await ref.read(storeRepositoryProvider).removeMember(member.id);
      await _load();
      if (mounted) showAppMessage(context, 'Teammate removed');
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _revokeInvite(PendingInviteRow invite) async {
    setState(() => _busyId = invite.id);
    try {
      await ref.read(storeRepositoryProvider).revokeInvitation(invite.id);
      await _load();
      if (mounted) showAppMessage(context, 'Invite revoked');
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _resendInvite(PendingInviteRow invite) async {
    setState(() => _busyId = invite.id);
    try {
      final row = await ref.read(storeRepositoryProvider).createInvitation(
            storeId: widget.storeId,
            email: invite.email,
            role: invite.role,
          );
      final token = row['token'] as String? ?? invite.token;
      final link = AppUrl.inviteLink(token);
      final inviter = ref.read(authRepositoryProvider).currentUser;
      final fullName = (inviter?.userMetadata?['full_name'] as String?)?.trim();
      final inviterName =
          (fullName != null && fullName.isNotEmpty) ? fullName : inviter?.email;
      final mail = await ref.read(storeRepositoryProvider).sendInviteEmail(
            email: invite.email,
            token: token,
            storeName: widget.storeName,
            role: invite.role.value,
            inviteUrl: link,
            inviterName: inviterName,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invite link'),
          content: InviteShareActions(
            email: invite.email,
            token: token,
            storeName: widget.storeName,
            emailed: mail.emailed,
            emailNote: mail.emailed
                ? null
                : (mail.message ??
                    'Configure RESEND_API_KEY on Supabase to auto-email invites.'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      if (msg.toLowerCase().contains('upgrade to premium') ||
          msg.toUpperCase().contains('FREE_TEAM_SEAT_LIMIT')) {
        await showUpgradePremiumDialog(
          context,
          reason: UpgradeReason.teamSeats,
          storeName: widget.storeName,
        );
      } else {
        showAppError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _invite() async {
    Navigator.pop(context);
    await showInviteTeammateDialog(context, ref);
  }

  Future<void> _setMyPin() async {
    final pin = await showPinPadDialog(
      context,
      title: 'Set cashier PIN',
      subtitle: '4–6 digits. Used to open/claim the register on this store.',
      confirmLabel: 'Continue',
    );
    if (pin == null || !mounted) return;
    final confirm = await showPinPadDialog(
      context,
      title: 'Confirm PIN',
      subtitle: 'Enter the same PIN again.',
      confirmLabel: 'Save PIN',
    );
    if (confirm == null || !mounted) return;
    if (confirm != pin) {
      showAppMessage(context, 'PINs didn’t match. Try again.', isError: true);
      return;
    }
    setState(() => _busyId = 'pin');
    try {
      await ref.read(storeRepositoryProvider).setMyStorePin(
            storeId: widget.storeId,
            pin: pin,
          );
      await _load();
      if (mounted) showAppMessage(context, 'Cashier PIN saved');
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _resetPin(TeamMemberRow member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset PIN?'),
        content: Text(
          'Clear the cashier PIN for ${member.displayName}. '
          'They’ll need to set a new one under Team.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = member.id);
    try {
      await ref.read(storeRepositoryProvider).adminClearMemberPin(member.id);
      await _load();
      if (mounted) showAppMessage(context, 'PIN cleared');
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    final memberCount = team?.members.length ?? 0;
    final inviteCount = team?.invitations.length ?? 0;

    return AlertDialog(
      title: const Text('Team'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.planTier == PlanTier.free
                  ? 'Free plan: up to 2 people (you + 1 teammate). Manage roles below or invite someone new.'
                  : 'Members and pending invites for ${widget.storeName}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.planTier == PlanTier.free) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showUpgradePremiumDialog(
                    context,
                    reason: UpgradeReason.teamSeats,
                    storeName: widget.storeName,
                  ),
                  icon: const Icon(Icons.workspace_premium_outlined, size: 16),
                  label: const Text('Need more seats?'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TabBar(
              controller: _tabs,
              labelColor: AppColors.ink,
              tabs: [
                Tab(text: 'Members ($memberCount)'),
                Tab(text: 'Pending ($inviteCount)'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: const TextStyle(color: AppColors.danger)),
                              TextButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _membersList(team!),
                            _invitesList(team),
                          ],
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busyId == 'pin' ? null : _setMyPin,
          child: const Text('Set my PIN'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(
          onPressed: _invite,
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Invite'),
        ),
      ],
    );
  }

  Widget _membersList(StoreTeamSnapshot team) {
    if (team.members.isEmpty) {
      return const Center(child: Text('No active members.'));
    }
    return ListView.separated(
      itemCount: team.members.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = team.members[i];
        final busy = _busyId == m.id;
        final editable = _canEditMember(m);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            m.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              if (m.email != null && m.email!.isNotEmpty && m.email != m.displayName)
                m.email!,
              if (m.isSelf) 'You',
              m.hasPin ? 'PIN set' : 'No PIN',
            ].where((e) => e.isNotEmpty).join(' · '),
          ),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!m.isSelf && m.hasPin)
                      IconButton(
                        tooltip: 'Reset PIN',
                        onPressed: () => _resetPin(m),
                        icon: const Icon(Icons.pin_outlined, size: 20),
                      ),
                    if (editable)
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<StoreRole>(
                          initialValue: m.role,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final r in _assignableRoles(m))
                              DropdownMenuItem(value: r, child: Text(r.value)),
                          ],
                          onChanged: (v) {
                            if (v != null) _changeRole(m, v);
                          },
                        ),
                      )
                    else
                      Chip(
                        label: Text(m.role.value),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (editable) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => _removeMember(m),
                        icon: const Icon(Icons.person_remove_outlined, size: 20),
                        color: AppColors.danger,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _invitesList(StoreTeamSnapshot team) {
    if (team.invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No pending invites.'),
            const SizedBox(height: 8),
            TextButton(onPressed: _invite, child: const Text('Invite teammate')),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: team.invitations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final inv = team.invitations[i];
        final busy = _busyId == inv.id;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(inv.email, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${inv.role.value} · pending'),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _resendInvite(inv),
                      child: const Text('Resend'),
                    ),
                    IconButton(
                      tooltip: 'Revoke',
                      onPressed: () => _revokeInvite(inv),
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.danger,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
