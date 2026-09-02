import 'app_url.dart';

/// Public legal document URLs (App Store / Play metadata + in-app links).
abstract final class LegalUrls {
  static String privacyPolicy() => '${AppUrl.publicOrigin()}/privacy';

  static String termsOfUse() => '${AppUrl.publicOrigin()}/terms';

  static Uri privacyPolicyUri() => Uri.parse(privacyPolicy());

  static Uri termsOfUseUri() => Uri.parse(termsOfUse());
}
