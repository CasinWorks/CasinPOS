import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/providers/session_providers.dart';
import '../../domain/enums.dart';
import 'billing_providers.dart';

enum UpgradeReason {
  teamSeats,
  monthlyTransactions,
  general,
}

/// Premium upgrade via Apple / Google IAP (RevenueCat). Mobile apps only.
Future<void> showUpgradePremiumDialog(
  BuildContext context, {
  UpgradeReason reason = UpgradeReason.general,
  String? storeName,
  String? storeId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => UpgradePremiumDialog(
      reason: reason,
      storeName: storeName,
      storeId: storeId,
    ),
  );
}

class UpgradePremiumDialog extends ConsumerStatefulWidget {
  const UpgradePremiumDialog({
    super.key,
    required this.reason,
    this.storeName,
    this.storeId,
  });

  final UpgradeReason reason;
  final String? storeName;
  final String? storeId;

  @override
  ConsumerState<UpgradePremiumDialog> createState() =>
      _UpgradePremiumDialogState();
}

class _UpgradePremiumDialogState extends ConsumerState<UpgradePremiumDialog> {
  bool _busy = false;
  String? _error;
  Package? _package;

  String get _headline => switch (widget.reason) {
        UpgradeReason.teamSeats => 'Need more team seats?',
        UpgradeReason.monthlyTransactions => 'Monthly sales limit reached',
        UpgradeReason.general => 'Upgrade to Premium',
      };

  String get _resolvedStoreId {
    final fromArg = widget.storeId?.trim();
    if (fromArg != null && fromArg.isNotEmpty) return fromArg;
    return ref.read(activeMembershipProvider)?.storeId ?? '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPackage());
  }

  Future<void> _loadPackage() async {
    final service = ref.read(revenueCatServiceProvider);
    await ref.read(revenueCatBootstrapProvider.future);
    if (!service.isConfigured) return;
    try {
      final pkg = await service.monthlyPremiumPackage();
      if (!mounted) return;
      setState(() => _package = pkg);
    } catch (_) {
      // Offerings may be empty until store consoles / RC dashboard are configured.
    }
  }

  Future<void> _finishIfPremium(String storeId, {String? syncError}) async {
    ref.invalidate(membershipsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final memberships = await ref.read(membershipsProvider.future);
    final isPremium = memberships.any(
      (m) => m.storeId == storeId && m.store.planTier == PlanTier.premium,
    );
    if (!mounted) return;
    if (isPremium) {
      Navigator.pop(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('You’re on Premium'),
          content: const Text(
            'This store is upgraded. Enjoy more seats, higher sales limits, '
            'and multi-branch tools.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _busy = false;
      _error = syncError ??
          'Apple may still have Premium, but this store is not unlocked yet. '
              'Tap Restore again in a few seconds.';
    });
  }

  Future<void> _purchase() async {
    final storeId = _resolvedStoreId;
    if (storeId.isEmpty) {
      setState(() => _error = 'No store selected.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(revenueCatServiceProvider);
      final ok = await service.purchaseMonthlyPremium(storeId: storeId);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error =
              'No Premium on this Apple ID yet. If you just saw “already '
              'subscribed”, tap Restore. Otherwise Subscribe again after the '
              'Sandbox period ends.';
        });
        return;
      }

      String? syncError;
      try {
        await syncPremiumEntitlementToStore(storeId: storeId);
      } catch (e) {
        syncError = friendlyError(
          e,
          fallback:
              'Apple has Premium, but we could not unlock this store yet. '
              'Tap Restore.',
        );
      }
      await _finishIfPremium(storeId, syncError: syncError);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e, fallback: 'Purchase failed');
      });
    }
  }

  Future<void> _restore() async {
    final storeId = _resolvedStoreId;
    if (storeId.isEmpty) {
      setState(() => _error = 'No store selected.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(revenueCatServiceProvider);
      final ok = await service.restorePurchases(storeId: storeId);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error =
              'RevenueCat does not see Premium on this login yet. '
              'Apple can still show the sub under Settings. Tap Subscribe — '
              'if Apple says you already own it, we will attach it to this store.';
        });
        return;
      }
      String? syncError;
      try {
        await syncPremiumEntitlementToStore(storeId: storeId);
      } catch (e) {
        syncError = friendlyError(
          e,
          fallback: 'Subscription found, but store unlock failed. Try again.',
        );
      }
      await _finishIfPremium(storeId, syncError: syncError);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e, fallback: 'Restore failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(revenueCatServiceProvider);
    ref.watch(revenueCatBootstrapProvider);
    final iapReady = service.isConfigured;
    final price = service.priceString(_package);
    final membership = ref.watch(activeMembershipProvider);
    final storeId = _resolvedStoreId;
    final alreadyPremium = membership != null &&
        membership.storeId == storeId &&
        membership.store.planTier == PlanTier.premium;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    if (alreadyPremium) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You’re on Premium',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This store already has Premium unlocked in CasinPOS.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    final body = iapReady
        ? 'Unlock Premium for this store. Billing goes through Apple or Google.\n\n'
            'Already subscribed on this phone? Tap Subscribe or Restore — '
            'we unlock this store without charging again until the period ends.'
        : kIsWeb
            ? 'Premium is sold only in the CasinPOS iOS and Android apps. '
                'Open the mobile app as the store Owner, then upgrade.'
            : 'This build has no RevenueCat API key. Relaunch with '
                'scripts/run_ios_billing.sh';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _headline,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (widget.storeName != null &&
                widget.storeName!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Store: ${widget.storeName!.trim()}',
                style: const TextStyle(
                  color: AppColors.slate500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What you get on Premium',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('· More than 2 team seats',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('· Higher monthly sales allowance',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('· Multi-branch, franchise & aggregate reports',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (price != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Premium monthly — $price',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: AppSpacing.md),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (iapReady) ...[
              FilledButton(
                onPressed: _busy ? null : _purchase,
                child: Text(
                  price == null ? 'Subscribe' : 'Subscribe — $price',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _restore,
                child: const Text('Restore purchases'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
            ] else
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
          ],
        ),
      ),
    );
  }
}
