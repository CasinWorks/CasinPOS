String? _pending;

void savePendingInviteToken(String? token) {
  final t = token?.trim();
  _pending = (t == null || t.isEmpty) ? null : t;
}

String? readPendingInviteToken() => _pending;

void clearPendingInviteToken() => _pending = null;
