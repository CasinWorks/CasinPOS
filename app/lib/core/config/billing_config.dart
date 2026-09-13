/// RevenueCat / StoreKit product & entitlement identifiers.
///
/// Must match App Store Connect + RevenueCat dashboard exactly.
abstract final class BillingConfig {
  /// Paid App Store / full-access product. IAP / RevenueCat disabled in shipping builds.
  static const iapEnabled = false;

  /// RevenueCat entitlement that unlocks CasinPOS Premium (legacy / dormant).
  static const premiumEntitlementId = 'premium';

  /// One-time Non-Consumable (App Store) / one-time product (Play).
  static const premiumLifetimeProductId = 'casinpos_premium_lifetime';

  /// Legacy auto-renewable product — still accepted for existing buyers.
  static const premiumMonthlyProductId = 'casinpos_premium_monthly';

  static const premiumProductIds = {
    premiumLifetimeProductId,
    premiumMonthlyProductId,
  };

  /// Fixed PH list price for Premium (web PayMongo + marketing copy).
  /// Apple/Google show the StoreKit / Play price tier you set in the consoles.
  static const premiumPhpPesos = 199.0;
  static const premiumPhpCentavos = 19900;
  static const premiumPhpLabel = '₱199';
  static const premiumPeriodLabel = 'paid app';

  /// Far-future period end so PayMongo expire jobs never demote lifetime.
  static const lifetimePeriodEndIso = '2099-12-31T23:59:59.000Z';

  /// Public SDK keys from RevenueCat → Project → API keys.
  /// Pass via --dart-define (never commit secret/server keys).
  ///
  /// Prefer platform keys (`appl_…` / `goog_…`). The unified
  /// [apiKey] / Test Store `test_…` key works for both during setup.
  static const apiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static const iosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static const androidApiKey =
      String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');

  static String get resolvedIosKey {
    final ios = iosApiKey.trim();
    if (ios.isNotEmpty) return ios;
    return apiKey.trim();
  }

  static String get resolvedAndroidKey {
    final android = androidApiKey.trim();
    if (android.isNotEmpty) return android;
    return apiKey.trim();
  }

  static bool get hasIosKey => resolvedIosKey.isNotEmpty;
  static bool get hasAndroidKey => resolvedAndroidKey.isNotEmpty;

  static bool isPremiumProductId(String? id) {
    final v = (id ?? '').trim();
    return v.isNotEmpty && premiumProductIds.contains(v);
  }
}
