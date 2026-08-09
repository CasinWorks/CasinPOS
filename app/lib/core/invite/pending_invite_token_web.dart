import 'package:web/web.dart' as web;

const _key = 'casinpos_pending_invite_token';

void savePendingInviteToken(String? token) {
  final t = token?.trim();
  if (t == null || t.isEmpty) {
    web.window.sessionStorage.removeItem(_key);
    return;
  }
  web.window.sessionStorage.setItem(_key, t);
}

String? readPendingInviteToken() {
  final t = web.window.sessionStorage.getItem(_key);
  if (t == null || t.trim().isEmpty) return null;
  return t.trim();
}

void clearPendingInviteToken() {
  web.window.sessionStorage.removeItem(_key);
}
