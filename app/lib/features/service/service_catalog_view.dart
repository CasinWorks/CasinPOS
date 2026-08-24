import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_models.dart';
import '../../../data/providers/service_providers.dart';
import '../../../data/providers/session_providers.dart';

class ServiceCatalogView extends ConsumerWidget {
  const ServiceCatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceCatalogProvider);
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Services',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(context, ref, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add service'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Fixed-price catalog. No stock or SKU — duration and price only.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No services yet. Add one to start booking.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = items[i];
                    return ListTile(
                      tileColor: AppColors.slate100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        '${s.durationMinutes} min · ${s.isActive ? 'Active' : 'Hidden'}',
                      ),
                      trailing: Text(
                        '₱${s.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () => _edit(context, ref, s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, ServiceOffering? existing) async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ServiceEditorDialog(existing: existing),
    );
    if (saved == true) {
      ref.invalidate(serviceCatalogProvider);
    }
  }
}

class _ServiceEditorDialog extends ConsumerStatefulWidget {
  const _ServiceEditorDialog({this.existing});

  final ServiceOffering? existing;

  @override
  ConsumerState<_ServiceEditorDialog> createState() => _ServiceEditorDialogState();
}

class _ServiceEditorDialogState extends ConsumerState<_ServiceEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _duration;
  late final TextEditingController _price;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _duration = TextEditingController(text: '${e?.durationMinutes ?? 60}');
    _price = TextEditingController(text: e == null ? '' : e.price.toStringAsFixed(2));
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New service' : 'Edit service'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
            ),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    try {
                      await ref.read(serviceRepositoryProvider).deleteService(widget.existing!.id);
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) showAppError(context, friendlyError(e));
                    }
                  },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final membership = ref.read(activeMembershipProvider);
                  if (membership == null) return;
                  final name = _name.text.trim();
                  if (name.isEmpty) return;
                  setState(() => _saving = true);
                  try {
                    await ref.read(serviceRepositoryProvider).upsertService(
                          storeId: membership.storeId,
                          id: widget.existing?.id,
                          name: name,
                          description: _desc.text,
                          durationMinutes: int.tryParse(_duration.text) ?? 60,
                          price: double.tryParse(_price.text.replaceAll(',', '')) ?? 0,
                          isActive: _active,
                        );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) showAppError(context, friendlyError(e));
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
