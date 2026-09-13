import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/billing_config.dart';
import '../../core/config/legal_urls.dart';
import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/store_models.dart';
import '../../data/providers/session_providers.dart';
import '../../domain/enums.dart';
import 'billing_providers.dart';
import 'paymongo_billing.dart';

enum UpgradeReason {
  teamSeats,
  monthlyTransactions,
  franchise,
  general,
}

/// Premium upgrade: Apple/Google IAP on mobile, PayMongo QR on web.
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
  PaymongoCheckout? _webCheckout;
  PaymongoPriceQuote? _webQuote;
  bool _polling = false;
  DateTime? _periodEndBefore;

  String get _headline => switch (widget.reason) {
        UpgradeReason.teamSeats => 'Need more team seats?',
        UpgradeReason.monthlyTransactions => 'Monthly sales limit reached',
        UpgradeReason.franchise => 'Open franchise stores with Premium',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        _loadWebQuote();
      } else {
        _loadPackage();
      }
    });
  }

  Future<void> _loadWebQuote() async {
    final storeId = _resolvedStoreId;
    if (storeId.isEmpty) return;
    try {
      final quote = await fetchPremiumPaymongoQuote(storeId: storeId);
      if (!mounted) return;
      setState(() => _webQuote = quote);
    } catch (_) {
      // Offer still shows ₱199; amount confirmed on the PayMongo sheet.
    }
  }

  Future<void> _loadPackage() async {
    final service = ref.read(revenueCatServiceProvider);
    await ref.read(revenueCatBootstrapProvider.future);
    if (!service.isConfigured) return;
    try {
      final pkg = await service.premiumPackage();
      if (!mounted) return;
      setState(() => _package = pkg);
    } catch (_) {
      // Offerings may be empty until store consoles / RC dashboard are configured.
    }
  }

  Future<void> _finishIfPremium(
    String storeId, {
    String? syncError,
    DateTime? requirePeriodAfter,
  }) async {
    ref.invalidate(membershipsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final memberships = await ref.read(membershipsProvider.future);
    StoreMembership? found;
    for (final m in memberships) {
      if (m.storeId == storeId) {
        found = m;
        break;
      }
    }
    final isPremium = found?.store.planTier == PlanTier.premium;
    final end = found?.store.premiumPeriodEnd;
    final periodOk = requirePeriodAfter == null ||
        (end != null && end.isAfter(requirePeriodAfter));
    if (!mounted) return;
    if (isPremium && periodOk) {
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
      _polling = false;
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
      // Purchase sheet (or “already subscribed”) → always try attach + server sync.
      await service.purchasePremium(storeId: storeId);
      await service.attachStorePurchasesToCurrentUser(storeId: storeId);

      String? syncError;
      try {
        await syncPremiumEntitlementToStore(storeId: storeId);
      } catch (e) {
        syncError = friendlyError(
          e,
          fallback:
              'Could not unlock this store yet. If Premium is on another '
              'CasinPOS store, set that one Free in Platform Ops first.',
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
              'Apple can still show the purchase under Settings. Tap Buy — '
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

  Future<void> _startWebCheckout() async {
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
      final current = ref.read(activeMembershipProvider);
      final already = current != null &&
          current.storeId == storeId &&
          current.store.planTier == PlanTier.premium;
      _periodEndBefore = already ? current.store.premiumPeriodEnd : null;
      final checkout = await createPremiumPaymongoCheckout(storeId: storeId);
      if (!mounted) return;
      setState(() {
        _webCheckout = checkout;
        _busy = false;
      });
      await _openCheckoutUrl(checkout.checkoutUrl);
      await _pollUntilPremium(storeId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e, fallback: 'Couldn’t start PayMongo checkout');
      });
    }
  }

  Future<void> _openCheckoutUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } catch (_) {}
  }

  Future<void> _pollUntilPremium(String storeId) async {
    if (_polling) return;
    setState(() => _polling = true);
    for (var i = 0; i < 90; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      ref.invalidate(membershipsProvider);
      try {
        final memberships = await ref.read(membershipsProvider.future);
        StoreMembership? found;
        for (final m in memberships) {
          if (m.storeId == storeId) {
            found = m;
            break;
          }
        }
        if (found?.store.planTier != PlanTier.premium) continue;
        final end = found!.store.premiumPeriodEnd;
        final required = _periodEndBefore;
        if (required != null && (end == null || !end.isAfter(required))) {
          continue;
        }
        setState(() => _polling = false);
        await _finishIfPremium(storeId, requirePeriodAfter: required);
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _polling = false;
      _error =
          'Still waiting for payment. If you already paid, tap Check payment.';
    });
  }

  Future<void> _checkPayment() async {
    final storeId = _resolvedStoreId;
    if (storeId.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _finishIfPremium(
      storeId,
      requirePeriodAfter: _periodEndBefore,
      syncError:
          'Payment not recorded yet. Finish checkout on your phone, then tap Check payment.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(revenueCatServiceProvider);
    if (!kIsWeb) ref.watch(revenueCatBootstrapProvider);
    final iapReady = service.isConfigured;
    final price = service.priceString(_package);
    final membership = ref.watch(activeMembershipProvider);
    final storeId = _resolvedStoreId;
    final alreadyPremium = membership != null &&
        membership.storeId == storeId &&
        membership.store.planTier == PlanTier.premium;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final pad = EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset);

    if (_webCheckout != null) {
      return Padding(padding: pad, child: _webPayBody());
    }

    if (alreadyPremium && kIsWeb && membership.store.isPaymongoPremium) {
      return Padding(
        padding: pad,
        child: _paymongoActiveBody(membership.store.premiumPeriodEnd),
      );
    }

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

    if (kIsWeb) {
      return Padding(padding: pad, child: _webOfferBody());
    }

    final body = iapReady
        ? 'Unlock Premium forever for this store with a one-time purchase. '
            'Billing goes through Apple or Google.\n\n'
            'Already purchased on this Apple ID / Google account? '
            'Tap Buy or Restore — we unlock this store without charging again.'
        : 'This build has no RevenueCat API key. Relaunch with '
            'scripts/run_ios_billing.sh';

    return Padding(
      padding: pad,
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
            _benefitsCard(
              price == null
                  ? 'Premium lifetime — ${BillingConfig.premiumPhpLabel} one-time'
                  : 'Premium lifetime — $price (one-time)',
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
                  price == null
                      ? 'Buy Premium — ${BillingConfig.premiumPhpLabel}'
                      : 'Buy Premium — $price',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _restore,
                child: const Text('Restore purchases'),
              ),
              const SizedBox(height: 8),
              _purchaseDisclosure(price),
              const SizedBox(height: 4),
              _legalLinks(),
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

  Widget _purchaseDisclosure(String? price) {
    final priceLabel = price ?? BillingConfig.premiumPhpLabel;
    return Text(
      'CasinPOS Premium Lifetime — one-time purchase ($priceLabel). '
      'Unlocks Premium for this store permanently. Payment is charged to your '
      'Apple ID or Google account at confirmation. Not a subscription — '
      'no auto-renewal. Restore purchases if you reinstall or switch devices.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.slate500,
            height: 1.4,
          ),
    );
  }

  Future<void> _openLegalUrl(Uri uri) async {
    if (kIsWeb) {
      final path = uri.path;
      if (path == '/privacy' || path == '/terms') {
        context.push(path);
        return;
      }
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _legalLinks() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => _openLegalUrl(LegalUrls.privacyPolicyUri()),
          child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
        ),
        const Text('·', style: TextStyle(color: AppColors.slate400)),
        TextButton(
          onPressed: () => _openLegalUrl(LegalUrls.termsOfUseUri()),
          child: const Text('Terms of Use', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _benefitsCard(String? priceLine) {
    return Container(
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
          Text('· Up to 100,000 paid sales per month (Free is 1,000)',
              style: Theme.of(context).textTheme.bodySmall),
          Text('· Multi-branch, franchise & aggregate reports',
              style: Theme.of(context).textTheme.bodySmall),
          if (priceLine != null) ...[
            const SizedBox(height: 10),
            Text(
              priceLine,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _webOfferBody() {
    return SingleChildScrollView(
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
          Text(
            'Pay on the web with GCash, Maya, QR Ph, or card. '
            'Premium is a one-time ${BillingConfig.premiumPhpLabel} unlock for this store. '
            'iPhone / Android purchases stay in the mobile apps.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          _benefitsCard(
            _webQuote?.priceLine ??
                'Premium lifetime — ${BillingConfig.premiumPhpLabel} one-time',
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
          FilledButton(
            onPressed: _busy ? null : _startWebCheckout,
            child: const Text('Pay with QR / GCash / Maya'),
          ),
          const SizedBox(height: 8),
          _legalLinks(),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }

  Widget _paymongoActiveBody(DateTime? periodEnd) {
    final until = periodEnd == null
        ? null
        : DateFormat.yMMMMd().format(periodEnd.toLocal());
    return SingleChildScrollView(
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
          Text(
            until == null
                ? 'This store is Premium (web billing via PayMongo).'
                : endLooksLifetime(periodEnd)
                    ? 'This store has lifetime Premium via PayMongo.'
                    : 'This store is billed on the web via PayMongo through $until.',
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
          const SizedBox(height: 20),
          if (!endLooksLifetime(periodEnd))
            FilledButton(
              onPressed: _busy ? null : _startWebCheckout,
              child: const Text('Unlock lifetime'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          if (!endLooksLifetime(periodEnd)) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }

  bool endLooksLifetime(DateTime? periodEnd) {
    if (periodEnd == null) return false;
    return periodEnd.year >= 2090;
  }

  Widget _webPayBody() {
    final checkout = _webCheckout!;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scan to pay ${checkout.amountLabel}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use GCash, Maya, QR Ph, or a card on your phone. '
            'Pay ${checkout.amountLabel} once for lifetime Premium. '
            'This screen unlocks Premium when PayMongo confirms payment.',
          ),
          const SizedBox(height: 16),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: checkout.checkoutUrl,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          if (_polling) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Text(
              'Waiting for payment…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate500),
            ),
          ],
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
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _openCheckoutUrl(checkout.checkoutUrl),
            child: const Text('Open payment page'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _checkPayment,
            child: const Text('Check payment'),
          ),
          TextButton(
            onPressed: _polling
                ? null
                : () => setState(() {
                      _webCheckout = null;
                      _error = null;
                    }),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
