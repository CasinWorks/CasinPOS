import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/platform_providers.dart';
import '../../data/providers/session_providers.dart';

/// Inbox for messages sent by Platform Ops to the active store.
class StoreNotificationsView extends ConsumerWidget {
  const StoreNotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    final storeId = membership?.storeId;
    if (storeId == null) {
      return const Center(child: Text('Select a store to see notifications.'));
    }

    final async = ref.watch(myStoreMessagesProvider(storeId));
    final fmt = DateFormat('MMM d, yyyy · h:mm a');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Messages from CasinPOS support',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(friendlyError(e), style: const TextStyle(color: AppColors.danger)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myStoreMessagesProvider(storeId));
                    await ref.read(myStoreMessagesProvider(storeId).future);
                  },
                  child: ListView.separated(
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final unread = m.isRead != true;
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            if (unread) {
                              try {
                                await ref
                                    .read(platformAdminRepositoryProvider)
                                    .markStoreMessageRead(m.id);
                                ref.invalidate(myStoreMessagesProvider(storeId));
                              } catch (e) {
                                if (context.mounted) showAppError(context, e);
                              }
                            }
                            if (!context.mounted) return;
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(m.subject),
                                content: SingleChildScrollView(
                                  child: Text(m.body, style: const TextStyle(height: 1.4)),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.slate200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (unread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: const BoxDecoration(
                                          color: AppColors.accentDeep,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        m.subject,
                                        style: TextStyle(
                                          fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate500,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fmt.format(m.createdAt),
                                  style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
