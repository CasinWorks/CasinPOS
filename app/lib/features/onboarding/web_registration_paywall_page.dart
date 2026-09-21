import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/billing_config.dart';
import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/powered_by_casinworks.dart';
import '../../data/models/store_models.dart';
import '../../data/providers/session_providers.dart';
import '../../domain/enums.dart';
import '../billing/upgrade_premium_dialog.dart';

/// Full-page gate: web owners must pay ₱199 PayMongo before using POS.
class WebRegistrationPaywallPage extends ConsumerWidget {
  const WebRegistrationPaywallPage({super.key});

  StoreMembership? _pending(List<StoreMembership> memberships) {
    for (final m in memberships) {
      if (m.store.needsWebRegistrationPayment) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(membershipsProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: membershipsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(friendlyError(e)),
              ),
              data: (memberships) {
                final pending = _pending(memberships);
                if (pending == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) context.go('/');
                  });
                  return const SizedBox.shrink();
                }

                final isOwner = pending.role == StoreRole.owner;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: BrandLogo(size: 96, radius: 20, shadow: true),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Activate your store',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        isOwner
                            ? 'Pay ${BillingConfig.premiumPhpLabel} once with GCash, Maya, '
                                'QR Ph, or card to unlock ${pending.store.name} on the web.'
                            : 'This store is waiting for the owner to complete the '
                                '${BillingConfig.premiumPhpLabel} web registration payment.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.scaffold,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pending.store.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Web registration · ${BillingConfig.premiumPhpLabel} one-time',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (isOwner)
                        FilledButton(
                          onPressed: () async {
                            await showUpgradePremiumDialog(
                              context,
                              reason: UpgradeReason.webRegistration,
                              storeName: pending.store.name,
                              storeId: pending.storeId,
                            );
                            ref.invalidate(membershipsProvider);
                            final next = await ref.read(membershipsProvider.future);
                            if (!context.mounted) return;
                            if (_pending(next) == null) {
                              context.go('/');
                            }
                          },
                          child: Text(
                            'Pay ${BillingConfig.premiumPhpLabel} with QR / GCash / Maya',
                          ),
                        )
                      else
                        const Text(
                          'Ask the store owner to sign in on the web and complete payment.',
                          style: TextStyle(color: AppColors.slate600),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(membershipsProvider),
                        child: const Text('I’ve paid — refresh'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(authRepositoryProvider).signOut();
                          } catch (_) {}
                          if (context.mounted) context.go('/login');
                        },
                        child: const Text('Sign out'),
                      ),
                      const PoweredByCasinworks(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
