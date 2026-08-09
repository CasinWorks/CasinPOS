/// Shown when the user opens/pastes `/invite` or `/join` without `?token=`.
const kInviteMissingTokenMessage =
    'This link is missing the invite token. Open the full link from the email, '
    'or ask your manager to resend.';

/// True when [raw] is an invite/join URL (or path) with no usable `token`.
bool isInviteUrlMissingToken(String? raw) {
  if (raw == null) return false;
  final t = raw.trim();
  if (t.isEmpty) return false;
  if (!_looksLikeInviteOrJoinUrl(t)) return false;
  return _rawTokenFromPossibleUrl(t) == null;
}

/// Normalize invite tokens from URLs, paste, email clients, and markdown.
///
/// Returns null for empty input, bare `/invite` or `/join` links (no token),
/// or values that are still URL-shaped after extraction (never treat a URL as a token).
String? sanitizeInviteToken(String? raw) {
  if (raw == null) return null;
  var t = raw.trim();
  if (t.isEmpty) return null;

  // Percent-decoding (only when encoded); ignore malformed sequences.
  if (t.contains('%')) {
    try {
      t = Uri.decodeQueryComponent(t).trim();
    } catch (_) {
      try {
        t = Uri.decodeComponent(t).trim();
      } catch (_) {}
    }
  }

  t = _stripWrappingPunctuation(t);
  if (t.isEmpty) return null;

  // Bare /invite or /join without ?token= → not a token (caller shows clear copy).
  if (isInviteUrlMissingToken(t)) return null;

  // Pasted full invite URL → extract token query / path segment.
  final fromUrl = _rawTokenFromPossibleUrl(t);
  if (fromUrl != null) {
    t = fromUrl;
    if (t.contains('%')) {
      try {
        t = Uri.decodeQueryComponent(t).trim();
      } catch (_) {}
    }
    t = _stripWrappingPunctuation(t);
  }

  // Soft hyphens / zero-width / whitespace injected by email line wraps.
  t = t.replaceAll(RegExp(r'[\s\u00ad\u200b\u200c\u200d\ufeff]+'), '');
  t = _stripWrappingPunctuation(t);

  // Never accept a leftover URL / path as a token.
  if (t.contains('://') ||
      t.contains('/') ||
      t.toLowerCase().contains('token=')) {
    return null;
  }

  return t.isEmpty ? null : t;
}

String _stripWrappingPunctuation(String input) {
  var t = input.trim();
  const wrappers = <String>[
    '"',
    "'",
    '`',
    '<',
    '>',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '.',
    ',',
    ';',
  ];
  var changed = true;
  while (changed && t.isNotEmpty) {
    changed = false;
    for (final w in wrappers) {
      if (t.startsWith(w)) {
        t = t.substring(1).trimLeft();
        changed = true;
      }
      if (t.endsWith(w)) {
        t = t.substring(0, t.length - 1).trimRight();
        changed = true;
      }
    }
  }
  return t.trim();
}

bool _looksLikeInviteOrJoinUrl(String t) {
  final lower = t.toLowerCase();
  return t.contains('://') ||
      lower.contains('/invite') ||
      lower.contains('/join') ||
      lower.contains('token=');
}

/// Returns the raw token substring from a URL-like string (not fully sanitized).
String? _rawTokenFromPossibleUrl(String t) {
  if (!_looksLikeInviteOrJoinUrl(t)) return null;

  try {
    final uri = Uri.parse(t.contains('://') ? t : 'https://local/$t');
    final q = uri.queryParameters['token'];
    if (q != null && q.trim().isNotEmpty) return q.trim();
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length >= 2 && segs[segs.length - 2] == 'invite') {
      final last = segs.last;
      // Path form /invite/:token — ignore bare /invite or /join.
      if (last != 'invite' && last != 'join' && last.trim().isNotEmpty) {
        return last.trim();
      }
    }
  } catch (_) {}

  final m = RegExp(
    r'[?&#]token=([^&\s#<>"\]]+)',
    caseSensitive: false,
  ).firstMatch(t);
  return m?.group(1)?.trim();
}
