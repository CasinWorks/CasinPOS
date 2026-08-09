import 'pending_invite_token_stub.dart'
    if (dart.library.html) 'pending_invite_token_web.dart' as impl;

/// Survives login/signup navigation (and full reloads on web via sessionStorage).
void savePendingInviteToken(String? token) => impl.savePendingInviteToken(token);

String? readPendingInviteToken() => impl.readPendingInviteToken();

void clearPendingInviteToken() => impl.clearPendingInviteToken();
