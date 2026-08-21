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
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      final key = defaultTargetPlatform == TargetPlatform.iOS
          ? BillingConfig.resolvedIosKey
          : BillingConfig.resolvedAndroidKey;
      if (key.isEmpty) return;
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

  bool hasPremium(CustomerInfo info) =>
      info.entitlements.active.containsKey(BillingConfig.premiumEntitlementId);

  Future<bool> refreshHasPremium() async {
    if (!isConfigured) return false;
    final info = await Purchases.getCustomerInfo();
    return hasPremium(info);
  }

  /// Purchases monthly Premium. Returns true if entitlement is active after.
  Future<bool> purchaseMonthlyPremium({required String storeId}) async {
    if (!isConfigured) {
      throw AppException(
        'In-app subscriptions are not available on this device yet.',
      );
    }
    await setStoreId(storeId);
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
      return hasPremium(result.customerInfo);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      throw AppException(
        e.message?.isNotEmpty == true
            ? e.message!
            : 'Purchase failed. Please try again.',
      );
    }
  }

  Future<bool> restorePurchases({required String storeId}) async {
    if (!isConfigured) {
      throw AppException(
        'Restore is only available in the iOS or Android app.',
      );
    }
    await setStoreId(storeId);
    try {
      final info = await Purchases.restorePurchases();
      return hasPremium(info);
    } on PlatformException catch (e) {
      throw AppException(
        e.message?.isNotEmpty == true
            ? e.message!
            : 'Could not restore purchases.',
      );
    }
  }

  String? priceString(Package? package) => package?.storeProduct.priceString;
}
