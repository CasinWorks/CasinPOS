import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_models.dart';
import '../../../data/providers/service_providers.dart';

/// Name / phone / email with suggestions from saved returning clients.
class ClientPickerFields extends ConsumerStatefulWidget {
  const ClientPickerFields({
    super.key,
    required this.name,
    required this.phone,
    this.email,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController? email;

  @override
  ConsumerState<ClientPickerFields> createState() => _ClientPickerFieldsState();
}

class _ClientPickerFieldsState extends ConsumerState<ClientPickerFields> {
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(serviceCustomersProvider).valueOrNull ?? const [];
    return Column(
      children: [
        RawAutocomplete<ServiceCustomer>(
          textEditingController: widget.name,
          focusNode: _nameFocus,
          displayStringForOption: (c) => c.name,
          optionsBuilder: (text) {
            final q = text.text.trim().toLowerCase();
            if (q.isEmpty) {
              return customers.take(8);
            }
            return customers.where((c) {
              final name = c.name.toLowerCase();
              final phone = (c.phone ?? '').toLowerCase();
              return name.contains(q) || phone.contains(q);
            }).take(8);
          },
          onSelected: (c) {
            widget.name.text = c.name;
            widget.phone.text = c.phone ?? '';
            if (widget.email != null) {
              widget.email!.text = c.email ?? '';
            }
          },
          fieldViewBuilder: (context, controller, focus, onSubmit) {
            return TextField(
              controller: controller,
              focusNode: focus,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Client name',
                helperText: 'Pick a returning client or type a new name',
              ),
              onSubmitted: (_) => onSubmit(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 420),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final c = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline, size: 20),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: c.subtitle.isEmpty
                            ? null
                            : Text(
                                c.subtitle,
                                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                              ),
                        onTap: () => onSelected(c),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        TextField(
          controller: widget.phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        if (widget.email != null)
          TextField(
            controller: widget.email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
      ],
    );
  }
}
