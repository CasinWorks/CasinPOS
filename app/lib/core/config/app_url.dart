import 'package:flutter/foundation.dart';

/// Public origin for invite / share links.
///
/// Override at build time:
///   `--dart-define=APP_URL=https://casin-pos-black.vercel.app`
///
/// On Flutter web, falls back to the current page origin when override is empty.
abstract final class AppUrl {
  static const String _override = String.fromEnvironment('APP_URL');
  static const String defaultProduction =
      'https://casin-pos-black.vercel.app';

  /// Origin only (no trailing slash), e.g. `https://casin-pos-black.vercel.app`.
  static String publicOrigin() {
    final fromEnv = _override.trim();
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      final base = Uri.base;
      final path = base.path;
      // Strip Flutter route path if any; keep origin (+ optional subdir base href).
      final origin = base.origin;
      if (path == '/' || path.isEmpty) return origin;
      // Subdirectory deploys: keep path up to last segment that isn't a route.
      return origin;
    }
    return defaultProduction;
  }

  /// Deep link that opens Join with the token pre-filled.
  static String inviteLink(String token) {
    final t = Uri.encodeQueryComponent(token.trim());
    return '${publicOrigin()}/invite?token=$t';
  }

  /// Password recovery redirect — must be allow-listed in Supabase Auth URL config.
  static String resetPasswordLink() => '${publicOrigin()}/reset-password';

  /// Friendly alias used in copy for humans; same destination as [inviteLink].
  static String joinLink(String token) {
    final t = Uri.encodeQueryComponent(token.trim());
    return '${publicOrigin()}/join?token=$t';
  }

  static Uri inviteMailto({
    required String toEmail,
    required String token,
    String? storeName,
  }) {
    final link = inviteLink(token);
    final store = (storeName == null || storeName.trim().isEmpty)
        ? 'CasinPOS'
        : storeName.trim();
    final subject = 'Join $store on CasinPOS';
    final body = 'You’re invited to join $store on CasinPOS.\n\n'
        '1. Open this link (copy the whole line):\n'
        '$link\n\n'
        '2. Create an account (or sign in) with this email: ${toEmail.trim()}\n'
        '3. You’re in — no token paste needed if you use the link.\n\n'
        'If the link doesn’t work, sign in at ${publicOrigin()} → Join your team,\n'
        'and paste this token (copy the whole line):\n'
        '${token.trim()}\n';
    return Uri(
      scheme: 'mailto',
      path: toEmail.trim(),
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
  }
}
