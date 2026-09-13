import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/config/billing_config.dart';
import '../../core/errors/app_errors.dart';

/// Thin RevenueCat wrapper. No-ops on web / when API keys are missing.
class RevenueCatService {
  bool _configured = false;

  bool get isSupported {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return BillingConfig.hasIosKey;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return BillingConfig.hasAndroidKey;
    }
    return false;
  }

  bool get isConfigured => _configured && isSupported;

  Future<void> configure() async {
    if (!BillingConfig.iapEnabled) return;
    if (!isSupported || _configured) return;
    try {
      final key = defaultTargetPlatform == TargetPlatform.iOS
          ? BillingConfig.resolvedIosKey
          : BillingConfig.resolvedAndroidKey;
      if (key.isEmpty) return;

      // RevenueCat fatally crashes Release/TestFlight builds that use a
      // Test Store key (test_…). Never call configure() with those in release.
      if (kReleaseMode && key.startsWith('test_')) {
        debugPrint(
          'CasinPOS: Skipping RevenueCat — Test Store key (test_…) cannot be '
          'used in TestFlight/App Store builds. Use the Apple appl_… / Google '
          'goog_… public SDK key from RevenueCat → Apps → API keys.',
        );
        return;
      }

      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      await Purchases.configure(PurchasesConfiguration(key));
      _configured = true;
    } catch (e, st) {
      debugPrint('RevenueCat configure failed: $e\n$st');
    }
  }

  Future<void> logIn(String appUserId) async {
    if (!isConfigured || appUserId.isEmpty) return;
    try {
      await Purchases.logIn(appUserId);
    } catch (e) {
      debugPrint('RevenueCat logIn failed: $e');
    }
  }

  Future<void> logOut() async {
    if (!isConfigured) return;
    try {
      if (await Purchases.isAnonymous) return;
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCat logOut failed: $e');
    }
  }

  Future<void> setStoreId(String storeId) async {
    if (!isConfigured || storeId.isEmpty) return;
    try {
      await Purchases.setAttributes({'store_id': storeId});
    } catch (e) {
      debugPrint('RevenueCat setAttributes failed: $e');
    }
  }

  /// Prefers lifetime package, then legacy monthly, then product-id match.
  Future<Package?> premiumPackage() async {
    if (!isConfigured) return null;
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) return null;

    final lifetime = current.lifetime;
    if (lifetime != null) return lifetime;

    for (final pkg in current.availablePackages) {
      if (pkg.storeProduct.identifier ==
          BillingConfig.premiumLifetimeProductId) {
        return pkg;
      }
    }

    final monthly = current.monthly;
    if (monthly != null) return monthly;

    for (final pkg in current.availablePackages) {
      if (BillingConfig.isPremiumProductId(pkg.storeProduct.identifier)) {
        return pkg;
      }
    }
    return current.availablePackages.isEmpty
        ? null
        : current.availablePackages.first;
  }

  @Deprecated('Use premiumPackage')
  Future<Package?> monthlyPremiumPackage() => premiumPackage();

  bool hasPremium(CustomerInfo info) {
    if (info.entitlements.active
        .containsKey(BillingConfig.premiumEntitlementId)) {
      return true;
    }
    for (final id in info.activeSubscriptions) {
      if (BillingConfig.isPremiumProductId(id)) return true;
    }
    for (final ent in info.entitlements.active.values) {
      if (BillingConfig.isPremiumProductId(ent.productIdentifier)) {
        return true;
      }
    }
    // Non-consumable lifetime purchases may only appear here.
    for (final tx in info.nonSubscriptionTransactions) {
      if (BillingConfig.isPremiumProductId(tx.productIdentifier)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> refreshHasPremium() async {
    if (!isConfigured) return false;
    final info = await Purchases.getCustomerInfo();
    return hasPremium(info);
  }

  /// Sync Apple receipt → this RevenueCat app user, then check Premium.
  Future<bool> attachStorePurchasesToCurrentUser({
    required String storeId,
  }) async {
    if (!isConfigured) return false;
    await setStoreId(storeId);
    try {
      var info = await Purchases.restorePurchases();
      if (hasPremium(info)) return true;
      info = await Purchases.getCustomerInfo();
      return hasPremium(info);
    } on PlatformException catch (e) {
      throw AppException(
        e.message?.isNotEmpty == true
            ? e.message!
            : 'Could not restore purchases.',
      );
    }
  }

  /// Purchases lifetime Premium (one-time). Returns true if entitlement is active.
  Future<bool> purchasePremium({required String storeId}) async {
    if (!isConfigured) {
      throw AppException(
        'In-app purchases are not available on this device yet.',
      );
    }
    await setStoreId(storeId);

    if (await refreshHasPremium()) {
      return true;
    }

    final package = await premiumPackage();
    if (package == null) {
      throw AppException(
        'Premium is not available yet. '
        'Check App Store Connect / RevenueCat offerings '
        '(product ${BillingConfig.premiumLifetimeProductId}).',
      );
    }
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      if (hasPremium(result.customerInfo)) return true;
      return attachStorePurchasesToCurrentUser(storeId: storeId);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError ||
          code == PurchasesErrorCode.productAlreadyPurchasedError) {
        return attachStorePurchasesToCurrentUser(storeId: storeId);
      }
      throw AppException(
        e.message?.isNotEmpty == true
            ? e.message!
            : 'Purchase failed. Please try again.',
      );
    }
  }

  @Deprecated('Use purchasePremium')
  Future<bool> purchaseMonthlyPremium({required String storeId}) =>
      purchasePremium(storeId: storeId);

  Future<bool> restorePurchases({required String storeId}) =>
      attachStorePurchasesToCurrentUser(storeId: storeId);

  String? priceString(Package? package) => package?.storeProduct.priceString;
}
