import 'invite_token.dart';
import 'pending_invite_token_stub.dart'
    if (dart.library.html) 'pending_invite_token_web.dart' as impl;

/// Survives login/signup navigation (and full reloads on web via sessionStorage).
void savePendingInviteToken(String? token) {
  final cleaned = sanitizeInviteToken(token);
  impl.savePendingInviteToken(cleaned);
}

String? readPendingInviteToken() {
  return sanitizeInviteToken(impl.readPendingInviteToken());
}

void clearPendingInviteToken() => impl.clearPendingInviteToken();

/// Capture invite token from the landing URI before go_router redirects (e.g. intro).
void captureInviteTokenFromUri(Uri uri) {
  String? candidate = uri.queryParameters['token'];
  if (candidate == null || candidate.trim().isEmpty) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length >= 2 && segs[segs.length - 2] == 'invite') {
      candidate = segs.last;
    }
  }
  // Flutter web sometimes parks leftovers on fragment: #/invite?token=
  if ((candidate == null || candidate.trim().isEmpty) &&
      uri.fragment.isNotEmpty) {
    final frag =
        uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
    try {
      final fragUri = Uri.parse('https://local$frag');
      candidate = fragUri.queryParameters['token'];
      if (candidate == null || candidate.trim().isEmpty) {
        final segs = fragUri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segs.length >= 2 && segs[segs.length - 2] == 'invite') {
          candidate = segs.last;
        }
      }
    } catch (_) {}
  }

  final cleaned = sanitizeInviteToken(candidate);
  if (cleaned != null) {
    savePendingInviteToken(cleaned);
  }
}
