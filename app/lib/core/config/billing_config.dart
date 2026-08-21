/// RevenueCat / StoreKit product & entitlement identifiers.
///
/// Must match App Store Connect + RevenueCat dashboard exactly.
abstract final class BillingConfig {
  /// RevenueCat entitlement that unlocks CasinPOS Premium.
  static const premiumEntitlementId = 'premium';

  /// App Store / Play product id for the monthly Premium subscription.
  static const premiumMonthlyProductId = 'casinpos_premium_monthly';

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
}
