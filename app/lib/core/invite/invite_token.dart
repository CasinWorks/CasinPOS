/// Normalize invite tokens from URLs, paste, email clients, and markdown.
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

/// Returns the raw token substring from a URL-like string (not fully sanitized).
String? _rawTokenFromPossibleUrl(String t) {
  final looksLikeUrl = t.contains('://') ||
      t.contains('/invite') ||
      t.contains('/join') ||
      t.toLowerCase().contains('token=');
  if (!looksLikeUrl) return null;

  try {
    final uri = Uri.parse(t.contains('://') ? t : 'https://local/$t');
    final q = uri.queryParameters['token'];
    if (q != null && q.trim().isNotEmpty) return q.trim();
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length >= 2 && segs[segs.length - 2] == 'invite') {
      return segs.last;
    }
  } catch (_) {}

  final m = RegExp(
    r'[?&#]token=([^&\s#<>"\]]+)',
    caseSensitive: false,
  ).firstMatch(t);
  return m?.group(1)?.trim();
}
