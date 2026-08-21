import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/session_providers.dart';
import '../../data/providers/ui_prefs_providers.dart';
import '../../domain/enums.dart';
import '../onboarding/story_mode.dart';

Future<void> showStoreSettingsDialog(BuildContext context, [WidgetRef? _]) async {
  // Always read via [context]'s ProviderScope — never a disposed sheet's WidgetRef.
  final container = ProviderScope.containerOf(context);
  final membership = container.read(activeMembershipProvider);
  if (membership == null) return;

  final narrow = MediaQuery.sizeOf(context).width < 600;
  final hostContext = context;

  if (narrow) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _StoreSettingsForm(
          hostContext: hostContext,
          asSheet: true,
        ),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Store settings'),
        content: SizedBox(
          width: 420,
          child: _StoreSettingsForm(
            hostContext: hostContext,
            asSheet: false,
          ),
        ),
      ),
    );
  }
}

class _StoreSettingsForm extends ConsumerStatefulWidget {
  const _StoreSettingsForm({
    required this.hostContext,
    required this.asSheet,
  });

  final BuildContext hostContext;
  final bool asSheet;

  @override
  ConsumerState<_StoreSettingsForm> createState() => _StoreSettingsFormState();
}

class _StoreSettingsFormState extends ConsumerState<_StoreSettingsForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tinCtrl;
  late final TextEditingController _addressCtrl;
  late final bool _canEdit;
  late final BusinessType _type;
  late final String _storeId;
  late final String _initialName;
  late final String _initialTin;
  late final String _initialAddress;
  late final bool _initialGcash;
  late final bool _initialMaya;
  late final bool _initialCard;

  var _acceptGcash = true;
  var _acceptMaya = true;
  var _acceptCard = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final membership = ref.read(activeMembershipProvider)!;
    _storeId = membership.storeId;
    _canEdit = membership.role.canInviteUsers;
    _type = membership.store.businessType;
    _initialName = membership.store.name;
    _initialTin = membership.store.businessTin ?? '';
    _initialAddress = membership.store.businessAddress ?? '';
    _initialGcash = membership.store.acceptGcash;
    _initialMaya = membership.store.acceptMaya;
    _initialCard = membership.store.acceptCard;
    _acceptGcash = _initialGcash;
    _acceptMaya = _initialMaya;
    _acceptCard = _initialCard;
    _nameCtrl = TextEditingController(text: _initialName);
    _tinCtrl = TextEditingController(text: _initialTin);
    _addressCtrl = TextEditingController(text: _initialAddress);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tinCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_saving || !_canEdit) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(storeRepositoryProvider);
      if (_nameCtrl.text.trim() != _initialName) {
        await repo.updateStoreName(storeId: _storeId, name: _nameCtrl.text);
      }
      final payChanged = _acceptGcash != _initialGcash ||
          _acceptMaya != _initialMaya ||
          _acceptCard != _initialCard;
      if (payChanged) {
        await repo.updatePaymentMethods(
          storeId: _storeId,
          acceptGcash: _acceptGcash,
          acceptMaya: _acceptMaya,
          acceptCard: _acceptCard,
        );
      }
      final tin = _tinCtrl.text.trim();
      final address = _addressCtrl.text.trim();
      final receiptChanged = tin != _initialTin || address != _initialAddress;
      if (receiptChanged) {
        await repo.updateReceiptFields(
          storeId: _storeId,
          businessTin: tin,
          businessAddress: address,
        );
      }

      if (!mounted) return;
      ref.invalidate(membershipsProvider);
      try {
        await ref.read(membershipsProvider.future).timeout(
              const Duration(seconds: 8),
            );
      } catch (_) {
        // Save already succeeded — don't block closing on a slow refresh.
      }

      if (!mounted) return;
      _close();
      if (widget.hostContext.mounted) {
        showAppMessage(widget.hostContext, 'Store settings saved');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(
        e,
        fallback: 'Could not save settings. Please try again.',
      );
      setState(() {
        _error = msg;
        _saving = false;
      });
      if (widget.hostContext.mounted) {
        showAppMessage(widget.hostContext, msg, isError: true);
      }
    }
  }

  Widget _fields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_canEdit) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Only the store Owner or Admin can edit TIN, address, and payments.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _nameCtrl,
          enabled: _canEdit,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Store name'),
        ),
        const SizedBox(height: 16),
        Text('Business type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.slate100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: [
              Icon(
                _type == BusinessType.retail
                    ? Icons.storefront_rounded
                    : Icons.restaurant_menu_rounded,
                size: 18,
                color: AppColors.slate700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _type == BusinessType.retail ? 'Retail' : 'Restaurant',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Text(
                'Locked',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chosen when the store was created and cannot be changed.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: 20),
        Text('Receipt legal fields (PH)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Shown on printed receipts. Use your BIR TIN and business address.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tinCtrl,
          enabled: _canEdit,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'TIN',
            hintText: '000-000-000-000',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _addressCtrl,
          enabled: _canEdit,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: 'Business address',
          ),
        ),
        const SizedBox(height: 20),
        Text('Display (this device)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Optional text size for POS, inventory, and menus. '
          'Saved on this device only — does not change prices or store data.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: 10),
        _textSizeControls(),
        const SizedBox(height: 12),
        Text('Payment methods', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Cash is always available. Enable the others your store accepts.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: true,
          onChanged: null,
          title: const Text('Cash', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Always on'),
          secondary: const Icon(Icons.payments_outlined),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _acceptGcash,
          onChanged: _canEdit ? (v) => setState(() => _acceptGcash = v) : null,
          title: const Text('GCash', style: TextStyle(fontWeight: FontWeight.w700)),
          secondary: const Icon(Icons.phone_android_outlined),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _acceptMaya,
          onChanged: _canEdit ? (v) => setState(() => _acceptMaya = v) : null,
          title: const Text('Maya', style: TextStyle(fontWeight: FontWeight.w700)),
          secondary: const Icon(Icons.account_balance_wallet_outlined),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _acceptCard,
          onChanged: _canEdit ? (v) => setState(() => _acceptCard = v) : null,
          title: const Text('Card', style: TextStyle(fontWeight: FontWeight.w700)),
          secondary: const Icon(Icons.credit_card_outlined),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: () {
                _close();
                if (widget.hostContext.mounted) {
                  widget.hostContext.push('/privacy');
                }
              },
              child: const Text('Privacy'),
            ),
            TextButton(
              onPressed: () {
                _close();
                if (widget.hostContext.mounted) {
                  widget.hostContext.push('/terms');
                }
              },
              child: const Text('Terms'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _textSizeControls() {
    final scale = ref.watch(appTextScaleProvider);
    final notifier = ref.read(appTextScaleProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in AppTextScaleNotifier.presets)
              ChoiceChip(
                label: Text(appTextScaleLabel(preset)),
                selected: (scale - preset).abs() < 0.03,
                onSelected: (_) => notifier.setScale(preset),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Expanded(
              child: Slider(
                value: scale.clamp(
                  AppTextScaleNotifier.min,
                  AppTextScaleNotifier.max,
                ),
                min: AppTextScaleNotifier.min,
                max: AppTextScaleNotifier.max,
                divisions: 10,
                label: '${(scale * 100).round()}%',
                onChanged: notifier.setScale,
              ),
            ),
            const Text('A', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: scale == 1.0 ? null : () => notifier.reset(),
            child: const Text('Reset to default'),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.asSheet) ...[
          if (_canEdit)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          TextButton(
            onPressed: _saving ? null : _close,
            child: const Text('Cancel'),
          ),
          if (_type == BusinessType.retail)
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      _close();
                      startRetailStory(ref);
                    },
              child: const Text('Replay story tutorial'),
            ),
        ] else
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              if (_type == BusinessType.retail)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          _close();
                          startRetailStory(ref);
                        },
                  child: const Text('Replay story tutorial'),
                ),
              TextButton(
                onPressed: _saving ? null : _close,
                child: const Text('Cancel'),
              ),
              if (_canEdit)
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSheet) {
      final maxH = MediaQuery.sizeOf(context).height * 0.92;
      return SizedBox(
        height: maxH,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Store settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: _fields(),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _footer(),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: SingleChildScrollView(child: _fields()),
        ),
        const SizedBox(height: 12),
        _footer(),
      ],
    );
  }
}
