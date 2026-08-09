import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/enums.dart';
import '../onboarding/story_mode.dart';

Future<void> showStoreSettingsDialog(BuildContext context, WidgetRef ref) async {
  final membership = ref.read(activeMembershipProvider);
  if (membership == null) return;

  final nameCtrl = TextEditingController(text: membership.store.name);
  var saving = false;
  String? error;
  final type = membership.store.businessType;
  final canEdit = membership.role.canInviteUsers;
  var acceptGcash = membership.store.acceptGcash;
  var acceptMaya = membership.store.acceptMaya;
  var acceptCard = membership.store.acceptCard;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Store settings'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      enabled: canEdit,
                      decoration: const InputDecoration(labelText: 'Store name'),
                    ),
                    const SizedBox(height: 16),
                    Text('Business type', style: Theme.of(ctx).textTheme.titleSmall),
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
                            type == BusinessType.retail
                                ? Icons.storefront_rounded
                                : Icons.restaurant_menu_rounded,
                            size: 18,
                            color: AppColors.slate700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              type == BusinessType.retail ? 'Retail' : 'Restaurant',
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
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                    ),
                    const SizedBox(height: 20),
                    Text('Payment methods', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Cash is always available. Enable the others your store accepts.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
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
                      value: acceptGcash,
                      onChanged: canEdit ? (v) => setLocal(() => acceptGcash = v) : null,
                      title: const Text('GCash', style: TextStyle(fontWeight: FontWeight.w700)),
                      secondary: const Icon(Icons.phone_android_outlined),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: acceptMaya,
                      onChanged: canEdit ? (v) => setLocal(() => acceptMaya = v) : null,
                      title: const Text('Maya', style: TextStyle(fontWeight: FontWeight.w700)),
                      secondary: const Icon(Icons.account_balance_wallet_outlined),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: acceptCard,
                      onChanged: canEdit ? (v) => setLocal(() => acceptCard = v) : null,
                      title: const Text('Card', style: TextStyle(fontWeight: FontWeight.w700)),
                      secondary: const Icon(Icons.credit_card_outlined),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: AppColors.danger)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (type == BusinessType.retail)
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          startRetailStory(ref);
                        },
                  child: const Text('Replay story tutorial'),
                ),
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (canEdit)
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setLocal(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            final repo = ref.read(storeRepositoryProvider);
                            if (nameCtrl.text.trim() != membership.store.name) {
                              await repo.updateStoreName(
                                storeId: membership.storeId,
                                name: nameCtrl.text,
                              );
                            }
                            final payChanged = acceptGcash != membership.store.acceptGcash ||
                                acceptMaya != membership.store.acceptMaya ||
                                acceptCard != membership.store.acceptCard;
                            if (payChanged) {
                              await repo.updatePaymentMethods(
                                storeId: membership.storeId,
                                acceptGcash: acceptGcash,
                                acceptMaya: acceptMaya,
                                acceptCard: acceptCard,
                              );
                            }
                            // Close before invalidating — rebuilding the shell under an open
                            // dialog caused InheritedWidget dispose asserts.
                            if (ctx.mounted) Navigator.pop(ctx);
                            ref.invalidate(membershipsProvider);
                          } catch (e) {
                            if (ctx.mounted) {
                              setLocal(() {
                                error = e.toString();
                                saving = false;
                              });
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
            ],
          );
        },
      );
    },
  );

  nameCtrl.dispose();
}
