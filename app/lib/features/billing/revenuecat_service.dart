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

  Future<Package?> monthlyPremiumPackage() async {
    if (!isConfigured) return null;
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) return null;

    final monthly = current.monthly;
    if (monthly != null) return monthly;

    for (final pkg in current.availablePackages) {
      if (pkg.storeProduct.identifier ==
          BillingConfig.premiumMonthlyProductId) {
        return pkg;
      }
    }
    return current.availablePackages.isEmpty
        ? null
        : current.availablePackages.first;
  }

  bool hasPremium(CustomerInfo info) {
    if (info.entitlements.active
        .containsKey(BillingConfig.premiumEntitlementId)) {
      return true;
    }
    // Fallback when entitlement mapping lags but StoreKit still reports the SKU.
    if (info.activeSubscriptions
        .contains(BillingConfig.premiumMonthlyProductId)) {
      return true;
    }
    for (final ent in info.entitlements.active.values) {
      if (ent.productIdentifier == BillingConfig.premiumMonthlyProductId) {
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

  /// Purchases monthly Premium. Returns true if entitlement is active after.
  ///
  /// Apple's "You are currently subscribed" sheet often returns as a cancel.
  /// We always re-check / restore afterward so the store can still unlock.
  Future<bool> purchaseMonthlyPremium({required String storeId}) async {
    if (!isConfigured) {
      throw AppException(
        'In-app subscriptions are not available on this device yet.',
      );
    }
    await setStoreId(storeId);

    if (await refreshHasPremium()) {
      return true;
    }

    final package = await monthlyPremiumPackage();
    if (package == null) {
      throw AppException(
        'Premium subscription is not available yet. '
        'Check App Store Connect / RevenueCat offerings.',
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
        // Cancelled sheet OR already-owned → still try to attach existing sub.
        return attachStorePurchasesToCurrentUser(storeId: storeId);
      }
      throw AppException(
        e.message?.isNotEmpty == true
            ? e.message!
            : 'Purchase failed. Please try again.',
      );
    }
  }

  Future<bool> restorePurchases({required String storeId}) =>
      attachStorePurchasesToCurrentUser(storeId: storeId);

  String? priceString(Package? package) => package?.storeProduct.priceString;
}
