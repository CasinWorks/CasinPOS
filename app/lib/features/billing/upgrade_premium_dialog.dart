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
  return showDialog<void>(
    context: context,
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
        if (mounted) setState(() => _busy = false);
        return;
      }

      String? syncError;
      try {
        await syncPremiumEntitlementToStore(storeId: storeId);
      } catch (e) {
        syncError = friendlyError(
          e,
          fallback:
              'Payment succeeded, but we could not unlock Premium yet. Tap Restore.',
        );
      }

      ref.invalidate(membershipsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final memberships =
          await ref.read(membershipsProvider.future);
      final updated = memberships.where((m) => m.storeId == storeId);
      final isPremium = updated.isNotEmpty &&
          updated.first.store.planTier == PlanTier.premium;

      if (!mounted) return;
      if (isPremium) {
        Navigator.pop(context);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You’re on Premium'),
            content: const Text(
              'Thanks! This store is upgraded. Enjoy more seats, higher '
              'sales limits, and multi-branch tools.',
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
            'Payment went through, but Premium is not active on this store yet. '
                'Tap Restore, or pull to refresh and try again in a few seconds.';
      });
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
              'No active Premium subscription found for this Apple ID yet.';
        });
        return;
      }
      try {
        await syncPremiumEntitlementToStore(storeId: storeId);
      } catch (_) {}
      ref.invalidate(membershipsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final memberships = await ref.read(membershipsProvider.future);
      final isPremium = memberships.any(
        (m) =>
            m.storeId == storeId && m.store.planTier == PlanTier.premium,
      );
      if (!mounted) return;
      if (isPremium) {
        Navigator.pop(context);
        showAppMessage(context, 'Premium is active for this store.');
        return;
      }
      setState(() {
        _busy = false;
        _error =
            'Subscription found in the App Store, but this store is not Premium yet. Try again in a few seconds.';
      });
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

    final body = iapReady
        ? 'Subscribe monthly to unlock Premium for this store. '
            'Billing is handled by the App Store or Google Play. '
            'Cancel anytime in your device subscription settings.'
        : kIsWeb
            ? 'Premium is sold only in the CasinPOS iOS and Android apps '
                '(App Store / Google Play subscriptions). '
                'Open the mobile app, sign in as the store Owner, then tap '
                'Upgrade to Premium.'
            : 'This build has no RevenueCat API key, so Subscribe is hidden.\n\n'
                'Stop the app and relaunch with:\n'
                'scripts/run_ios_billing.sh\n'
                '(or flutter run --dart-define-from-file=../.env.flutter.local)';

    return AlertDialog(
      title: Text(_headline),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                style: TextStyle(
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(iapReady ? 'Not now' : 'OK'),
        ),
        if (iapReady) ...[
          TextButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Restore'),
          ),
          FilledButton(
            onPressed: _busy ? null : _purchase,
            child: Text(
              price == null ? 'Subscribe' : 'Subscribe — $price',
            ),
          ),
        ],
      ],
    );
  }
}
