import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_errors.dart';
import '../../core/input/numeric_formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/pos_models.dart';
import '../../data/providers/pos_providers.dart';
import '../../data/providers/session_providers.dart';

class DiscountCodesView extends ConsumerWidget {
  const DiscountCodesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(discountCodesProvider);
    final canManage =
        ref.watch(activeMembershipProvider)?.role.canInviteUsers == true;

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promos & discount codes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create % or fixed ₱ codes for cashiers to apply at checkout.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              if (canManage)
                FilledButton.icon(
                  onPressed: () => _openEditor(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New code'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!canManage)
            const Text(
              'Only Owner or Admin can create discount codes. You can still apply active codes in the cart.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          if (codes.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'No discount codes yet. Add SENIOR20-style codes here — they replace the old hardcoded chips.',
                style: TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
            )
          else
            for (final code in codes) ...[
              _CodeTile(
                code: code,
                canManage: canManage,
                onEdit: () => _openEditor(context, ref, existing: code),
                onToggle: canManage
                    ? () async {
                        try {
                          await ref.read(discountCodesProvider.notifier).upsert(
                                code.copyWith(isActive: !code.isActive),
                              );
                        } catch (e) {
                          if (context.mounted) showAppError(context, e);
                        }
                      }
                    : null,
                onDelete: canManage
                    ? () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete code?'),
                            content: Text('Remove ${code.code}? Cashiers won’t see it anymore.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        try {
                          await ref.read(discountCodesProvider.notifier).remove(code.id);
                        } catch (e) {
                          if (context.mounted) showAppError(context, e);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    DiscountCode? existing,
  }) async {
    final storeId = ref.read(activeMembershipProvider)?.storeId;
    if (storeId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DiscountCodeEditorSheet(
        storeId: storeId,
        existing: existing,
      ),
    );
  }
}

class _CodeTile extends StatelessWidget {
  const _CodeTile({
    required this.code,
    required this.canManage,
    required this.onEdit,
    this.onToggle,
    this.onDelete,
  });

  final DiscountCode code;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy · h:mm a');
    final window = [
      if (code.startsAt != null) 'from ${fmt.format(code.startsAt!.toLocal())}',
      if (code.endsAt != null) 'until ${fmt.format(code.endsAt!.toLocal())}',
    ].join(' ');

    return Material(
      color: code.isActive && code.isValidAt()
          ? const Color(0xFFECFDF5)
          : AppColors.slate100,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: canManage ? onEdit : null,
        title: Text(
          code.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            code.isActive ? (code.isValidAt() ? 'Active' : 'Inactive window') : 'Disabled',
            if (window.isNotEmpty) window,
          ].join(' · '),
          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
        ),
        trailing: canManage
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: code.isActive,
                    onChanged: onToggle == null ? null : (_) => onToggle!(),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _DiscountCodeEditorSheet extends ConsumerStatefulWidget {
  const _DiscountCodeEditorSheet({required this.storeId, this.existing});

  final String storeId;
  final DiscountCode? existing;

  @override
  ConsumerState<_DiscountCodeEditorSheet> createState() =>
      _DiscountCodeEditorSheetState();
}

class _DiscountCodeEditorSheetState
    extends ConsumerState<_DiscountCodeEditorSheet> {
  late final TextEditingController _code;
  late final TextEditingController _value;
  late DiscountKind _kind;
  late bool _active;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _value = TextEditingController(
      text: e == null
          ? ''
          : (e.value == e.value.roundToDouble()
              ? e.value.toStringAsFixed(0)
              : e.value.toStringAsFixed(2)),
    );
    _kind = e?.kind ?? DiscountKind.percent;
    _active = e?.isActive ?? true;
    _startsAt = e?.startsAt;
    _endsAt = e?.endsAt;
  }

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool start}) async {
    final initial = (start ? _startsAt : _endsAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startsAt = combined;
      } else {
        _endsAt = combined;
      }
    });
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    final value = NumericInput.tryParseMoney(_value.text);
    if (code.length < 2) {
      showAppMessage(context, 'Enter a code (min 2 characters)', isError: true);
      return;
    }
    if (value == null || value <= 0) {
      showAppMessage(context, 'Enter a valid discount value', isError: true);
      return;
    }
    if (_kind == DiscountKind.percent && value > 100) {
      showAppMessage(context, 'Percent cannot exceed 100', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(discountCodesProvider.notifier).upsert(
            DiscountCode(
              id: widget.existing?.id ?? const Uuid().v4(),
              storeId: widget.storeId,
              code: code,
              kind: _kind,
              value: value,
              isActive: _active,
              startsAt: _startsAt,
              endsAt: _endsAt,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showAppError(context, e, fallback: 'Could not save discount code.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final fmt = DateFormat('MMM d, yyyy · h:mm a');
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existing == null ? 'New discount code' : 'Edit discount code',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    hintText: 'e.g. SENIOR20',
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<DiscountKind>(
                  segments: const [
                    ButtonSegment(
                      value: DiscountKind.percent,
                      label: Text('% off'),
                      icon: Icon(Icons.percent, size: 16),
                    ),
                    ButtonSegment(
                      value: DiscountKind.fixed,
                      label: Text('₱ off'),
                      icon: Icon(Icons.payments_outlined, size: 16),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _value,
                  keyboardType: NumericInput.moneyKeyboard,
                  inputFormatters: NumericInput.money(),
                  decoration: InputDecoration(
                    labelText: _kind == DiscountKind.percent
                        ? 'Percent (1–100)'
                        : 'Amount off (₱)',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle: Text(
                    _startsAt == null ? 'Anytime' : fmt.format(_startsAt!.toLocal()),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_startsAt != null)
                        IconButton(
                          onPressed: () => setState(() => _startsAt = null),
                          icon: const Icon(Icons.clear),
                        ),
                      IconButton(
                        onPressed: () => _pickDateTime(start: true),
                        icon: const Icon(Icons.event),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends'),
                  subtitle: Text(
                    _endsAt == null ? 'No end' : fmt.format(_endsAt!.toLocal()),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_endsAt != null)
                        IconButton(
                          onPressed: () => setState(() => _endsAt = null),
                          icon: const Icon(Icons.clear),
                        ),
                      IconButton(
                        onPressed: () => _pickDateTime(start: false),
                        icon: const Icon(Icons.event),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
