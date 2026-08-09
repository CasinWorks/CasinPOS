import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_url.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/invite/invite_share_actions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/touch_targets.dart';
import '../../../data/models/store_models.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/permissions.dart';
import '../auth/confirm_password.dart';

Future<void> showFranchiseDialog(BuildContext context, WidgetRef ref) async {
  final membership = ref.read(activeMembershipProvider);
  if (membership == null ||
      !Permissions.canOpenFranchise(
        membership.role,
        storeIsFranchise: membership.store.isFranchise,
      )) {
    showAppMessage(
      context,
      'Only Owner or Admin of the main store can open a franchise.',
      isError: true,
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => _FranchiseDialog(storeId: membership.storeId),
  );
}

class _FranchiseDialog extends ConsumerStatefulWidget {
  const _FranchiseDialog({required this.storeId});

  final String storeId;

  @override
  ConsumerState<_FranchiseDialog> createState() => _FranchiseDialogState();
}

class _FranchiseDialogState extends ConsumerState<_FranchiseDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _copyStock = true;
  bool _loading = false;
  bool _loadingList = true;
  String? _deletingId;
  String? _error;
  FranchiseCreateResult? _result;
  bool? _inviteEmailed;
  String? _inviteEmailNote;
  List<FranchiseStoreSummary> _franchises = const [];

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshList() async {
    setState(() => _loadingList = true);
    try {
      final rows = await ref
          .read(storeRepositoryProvider)
          .listFranchiseStores(widget.storeId);
      if (mounted) setState(() => _franchises = rows);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _inviteEmailed = null;
      _inviteEmailNote = null;
    });
    try {
      final result = await ref.read(storeRepositoryProvider).createFranchiseStore(
            franchisorStoreId: widget.storeId,
            ownerEmail: _emailCtrl.text,
            storeName: _nameCtrl.text,
            copyStock: _copyStock,
            notes: _notesCtrl.text,
          );
      if (!mounted) return;
      bool? emailed;
      String? emailNote;
      if (result.inviteToken != null && !result.ownerLinked) {
        final link = AppUrl.inviteLink(result.inviteToken!);
        final inviter = ref.read(authRepositoryProvider).currentUser;
        final fullName =
            (inviter?.userMetadata?['full_name'] as String?)?.trim();
        final inviterName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : inviter?.email;
        final mail = await ref.read(storeRepositoryProvider).sendInviteEmail(
              email: result.ownerEmail,
              token: result.inviteToken!,
              storeName: result.storeName,
              role: 'owner',
              inviteUrl: link,
              inviterName: inviterName,
            );
        emailed = mail.emailed;
        emailNote = mail.emailed
            ? null
            : (mail.message ??
                'Configure RESEND_API_KEY on Supabase to auto-email invites.');
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _inviteEmailed = emailed;
        _inviteEmailNote = emailNote;
      });
      await _refreshList();
      if (!mounted) return;
      showAppMessage(
        context,
        result.ownerLinked
            ? 'Franchise opened — owner already linked. ${result.productsCloned} products cloned.'
            : (emailed == true
                ? 'Franchise opened — invite email sent to ${result.ownerEmail}.'
                : 'Franchise opened — share the invite link with ${result.ownerEmail}.'),
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFranchise(FranchiseStoreSummary franchise) async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null ||
        !Permissions.canOpenFranchise(
          membership.role,
          storeIsFranchise: membership.store.isFranchise,
        )) {
      showAppMessage(
        context,
        'Only Owner or Admin of the main store can remove a franchise.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete franchise'),
        content: Text(
          'Delete this franchise permanently? This cannot be undone.\n\n'
          '“${franchise.name}” and all of its products, team access, and sales will be removed.',
          style: const TextStyle(fontSize: 14, color: AppColors.slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: TouchTargets.buttonMin),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: TouchTargets.buttonMin,
              padding: TouchTargets.buttonPadding,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final email = ref.read(authRepositoryProvider).currentUser?.email?.trim() ?? '';
    final authOk = await confirmSignedInPassword(
      context,
      ref,
      title: 'Confirm with password',
      body: 'Re-enter your password for $email to delete this franchise.',
    );
    if (!authOk || !mounted) return;

    setState(() => _deletingId = franchise.id);
    try {
      final deleted =
          await ref.read(storeRepositoryProvider).deleteFranchiseStore(franchise.id);
      if (!mounted) return;
      // Update local list first — never invalidate shell providers under this dialog.
      setState(() {
        _franchises = _franchises.where((f) => f.id != franchise.id).toList();
        if (_result?.storeId == franchise.id) _result = null;
      });
      showAppMessage(context, '“${deleted.name}” removed');
      // Soft refresh list after the delete dialogs are already closed.
      await _refreshList();
    } catch (e) {
      if (mounted) showAppError(context, e, fallback: 'Could not delete franchise');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Franchise'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Open a franchise store for a partner. Catalog (products, prices, '
                  'SKUs, categories, images) is cloned; stock levels stay independent after that.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Franchise store name',
                    hintText: 'e.g. Cascade Café — Makati',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Store name is required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Franchisee owner email',
                    hintText: 'owner@example.com',
                  ),
                  validator: (v) {
                    final email = v?.trim() ?? '';
                    if (email.isEmpty) return 'Email is required';
                    if (!email.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Location, agreement ref…',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _copyStock,
                  onChanged: _loading ? null : (v) => setState(() => _copyStock = v),
                  title: const Text(
                    'Copy current stock quantities',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _copyStock
                        ? 'Initial stock matches the main store. Franchisee stock changes independently.'
                        : 'Products clone with stock set to 0. Franchisee can adjust later.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                if (_result != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SuccessBanner(
                    result: _result!,
                    emailed: _inviteEmailed,
                    emailNote: _inviteEmailNote,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Your franchises', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                if (_loadingList)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_franchises.isEmpty)
                  Text(
                    'No franchises yet.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                  )
                else
                  ..._franchises.map(
                    (f) => _FranchiseListTile(
                      franchise: f,
                      deleting: _deletingId == f.id,
                      onRemove: (_loading || _deletingId != null)
                          ? null
                          : () => _removeFranchise(f),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_loading || _deletingId != null) ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: TouchTargets.buttonMin,
            padding: TouchTargets.buttonPadding,
          ),
          onPressed: (_loading || _deletingId != null) ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Open franchise'),
        ),
      ],
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({
    required this.result,
    this.emailed,
    this.emailNote,
  });

  final FranchiseCreateResult result;
  final bool? emailed;
  final String? emailNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.ownerLinked
                ? 'Owner linked — they can sign in and use “${result.storeName}”.'
                : 'Invite created for ${result.ownerEmail}. They open the join link, '
                    'sign up/in with that email, and they’re in.',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '${result.productsCloned} products · ${result.categoriesCloned} categories cloned'
            '${result.copyStock ? ' · stock copied' : ' · stock set to 0'}.',
            style: const TextStyle(fontSize: 12, color: AppColors.slate600),
          ),
          if (result.inviteToken != null) ...[
            const SizedBox(height: 8),
            InviteShareActions(
              email: result.ownerEmail,
              token: result.inviteToken!,
              storeName: result.storeName,
              emailed: emailed,
              emailNote: emailNote,
            ),
          ],
        ],
      ),
    );
  }
}

class _FranchiseListTile extends StatelessWidget {
  const _FranchiseListTile({
    required this.franchise,
    required this.deleting,
    this.onRemove,
  });

  final FranchiseStoreSummary franchise;
  final bool deleting;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final pending = franchise.inviteStatus == 'pending' && franchise.inviteToken != null;
    final statusLabel = franchise.ownerLinked
        ? 'Active'
        : (pending ? 'Invite pending' : (franchise.inviteStatus ?? 'Pending'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      franchise.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: franchise.ownerLinked ? const Color(0xFF047857) : AppColors.slate500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (deleting)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Remove franchise',
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${franchise.ownerEmail ?? '—'} · ${franchise.productsCount} products',
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
              if (pending) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onRemove == null
                            ? null
                            : () async {
                                final link =
                                    AppUrl.inviteLink(franchise.inviteToken!);
                                await Clipboard.setData(ClipboardData(text: link));
                                if (context.mounted) {
                                  showAppMessage(context, 'Invite link copied');
                                }
                              },
                        icon: const Icon(Icons.link, size: 14),
                        label: const Text('Copy link'),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onRemove == null
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: franchise.inviteToken!),
                                );
                                if (context.mounted) {
                                  showAppMessage(context, 'Invite token copied');
                                }
                              },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy token'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
