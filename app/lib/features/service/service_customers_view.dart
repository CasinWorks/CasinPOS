import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_models.dart';
import '../../../data/providers/service_providers.dart';
import '../../../data/providers/session_providers.dart';

class ServiceCustomersView extends ConsumerWidget {
  const ServiceCustomersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceCustomersProvider);
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
                    'Customers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(context, ref, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Saved automatically from quotes and bookings. Pick them when a client returns.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (customers) {
                if (customers.isEmpty) {
                  return const Center(child: Text('No saved customers yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = customers[i];
                    return ListTile(
                      tileColor: AppColors.slate100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(c.subtitle.isEmpty ? 'No phone or email' : c.subtitle),
                      onTap: () => _edit(context, ref, c),
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
}

Future<void> _edit(BuildContext context, WidgetRef ref, ServiceCustomer? existing) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _CustomerEditorDialog(existing: existing),
  );
  if (saved == true) ref.invalidate(serviceCustomersProvider);
}

class _CustomerEditorDialog extends ConsumerStatefulWidget {
  const _CustomerEditorDialog({this.existing});

  final ServiceCustomer? existing;

  @override
  ConsumerState<_CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends ConsumerState<_CustomerEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _email = TextEditingController(text: widget.existing?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New customer' : 'Edit customer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
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
                    await ref.read(serviceRepositoryProvider).deleteCustomer(widget.existing!.id);
                    if (context.mounted) Navigator.pop(context, true);
                  },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final membership = ref.read(activeMembershipProvider);
                  if (membership == null || _name.text.trim().isEmpty) return;
                  setState(() => _saving = true);
                  try {
                    await ref.read(serviceRepositoryProvider).upsertCustomer(
                          storeId: membership.storeId,
                          name: _name.text,
                          phone: _phone.text,
                          email: _email.text,
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
