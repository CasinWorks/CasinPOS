import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppException implements Exception {
  AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class StockLimitException extends AppException {
  StockLimitException(super.message);
}

/// Default copy when the device can't reach Supabase / the internet.
const kOfflineFriendlyMessage =
    'You’re offline or the server can’t be reached. Check your connection and try again.';

const kOfflineQueuedSaleMessage =
    'Sale saved on this device — it will sync when you’re back online.';

String friendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is AppException) return error.message;

  // Prefer structured Postgrest / Function fields when present (avoids raw dumps).
  final structured = _structuredErrorBlob(error);
  final raw = structured ?? error.toString();
  final typeName = error.runtimeType.toString();

  final offline = _offlineOrNetworkMessage('$typeName $raw');
  if (offline != null) return offline;

  final mapped = mapKnownBackendError(raw);
  if (mapped != null) return mapped;

  // Strip noisy Exception: prefixes from Supabase / Dart.
  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^StateError:\s*'), '')
      .replaceFirst(RegExp(r'^Bad state:\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException\([^)]*\):\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException:\s*'), '')
      .replaceFirst(RegExp(r'^PostgresException\([^)]*\):\s*'), '')
      .replaceFirst(RegExp(r'^PostgresException:\s*'), '')
      .replaceFirst(RegExp(r'^AuthException\([^)]*\):\s*'), '')
      .replaceFirst(RegExp(r'^AuthException:\s*'), '')
      .replaceFirst(RegExp(r'^AuthApiException\([^)]*\):\s*'), '')
      .replaceFirst(RegExp(r'^AuthApiException:\s*'), '')
      .replaceFirst(RegExp(r'^AuthRetryableFetchException:\s*'), '')
      .replaceFirst(RegExp(r'^ClientException:\s*'), '')
      .replaceFirst(RegExp(r'^SocketException:\s*'), '')
      .replaceFirst(RegExp(r'^HttpException:\s*'), '')
      .replaceFirst(RegExp(r'^TimeoutException:\s*'), '')
      .trim();

  final offlineCleaned = _offlineOrNetworkMessage(cleaned);
  if (offlineCleaned != null) return offlineCleaned;

  final remapped = mapKnownBackendError(cleaned);
  if (remapped != null) return remapped;
  if (cleaned.isEmpty) return fallback;

  // Never surface raw unique-constraint / Postgres / HTTP / platform noise.
  if (_looksLikeSystemNoise(raw) || _looksLikeSystemNoise(cleaned)) {
    return fallback;
  }

  // Allow only short, plain product copy (no stack-ish / code-ish dumps).
  if (cleaned.length <= 160 && !_looksLikeSystemNoise(cleaned)) {
    return cleaned;
  }
  return fallback;
}

/// True when [raw] looks like a connectivity / DNS / TLS failure.
String? _offlineOrNetworkMessage(String raw) {
  final s = raw.toLowerCase();
  const needles = [
    'socketexception',
    'clientexception',
    'httpexception',
    'timeoutexception',
    'handshakeexception',
    'tls exception',
    'failed host lookup',
    'network is unreachable',
    'network unreachable',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection abort',
    'software caused connection abort',
    'broken pipe',
    'nodename nor servname',
    'name or service not known',
    'temporary failure in name resolution',
    'errno = 7',
    'errno = 8',
    'errno = 51',
    'errno = 61',
    'errno = 101',
    'errno = 104',
    'errno = 110',
    'errno = 111',
    'xmlhttprequest error',
    'failed to fetch',
    'network request failed',
    'networkerror',
    'authretryablefetchexception',
    'os error:',
    'no address associated with hostname',
    'unreachable host',
    'host is down',
    'timed out',
    'connection timed out',
    'receive timed out',
    'send timed out',
  ];
  for (final n in needles) {
    if (s.contains(n)) return kOfflineFriendlyMessage;
  }
  return null;
}

bool _looksLikeSystemNoise(String raw) {
  final s = raw.toLowerCase();
  const needles = [
    'socketexception',
    'clientexception',
    'httpexception',
    'timeoutexception',
    'handshakeexception',
    'postgresexception',
    'postgrestexception',
    'functionexception',
    'authapiexception',
    'authretryable',
    'platformexception',
    'missingpluginexception',
    'formatexception',
    'typeerror',
    'nosuchmethod',
    'rangeerror',
    'stateerror',
    'assertion failed',
    'stack overflow',
    'null check operator',
    'violates unique constraint',
    'duplicate key value',
    '23505',
    'pgrst',
    'sqlstate',
    'minified:',
    'status: 5',
    'statuscode',
    'http 5',
    'errno =',
    '#0 ',
    'package:',
    'dart:',
    'flutter error',
    'another exception was thrown',
  ];
  for (final n in needles) {
    if (s.contains(n)) return true;
  }
  // Looks like a JSON / code dump.
  if (raw.contains('{') && raw.contains('}') && raw.length > 80) return true;
  if (RegExp(r'\b[A-Z][a-zA-Z]+Exception\b').hasMatch(raw)) return true;
  return false;
}

/// Maps known RPC / auth exception codes to short UI copy. Returns null if unknown.
String? mapKnownBackendError(String raw) {
  final s = raw.toUpperCase();
  if (s.contains('42501') ||
      s.contains('ROW-LEVEL SECURITY') ||
      s.contains('ROW LEVEL SECURITY')) {
    return 'Couldn’t save — you don’t have permission for this store’s inventory. '
        'Sign out/in, or ask the store owner to re-invite you.';
  }
  if (s.contains('STORAGEEXCEPTION') ||
      (s.contains('UNAUTHORIZED') && s.contains('STORAGE'))) {
    return 'Photo upload failed. Apply Script I in Supabase (product-images bucket), then retry.';
  }
  if (s.contains('BUSINESS_TIN') ||
      s.contains('BUSINESS_ADDRESS') ||
      (s.contains('SCHEMA CACHE') &&
          (s.contains('TIN') || s.contains('ADDRESS')))) {
    return 'Receipt TIN/address columns are missing. Run Script B in the Supabase SQL Editor, then try again.';
  }
  if (s.contains('FORBIDDEN')) {
    return 'You don’t have permission to do that.';
  }
  if (s.contains('CANNOT_INVITE_OWNER')) {
    return 'You can’t invite someone as Owner. Use Admin, Manager, or Staff.';
  }
  if (s.contains('ADMIN_CANNOT_INVITE_ADMIN')) {
    return 'Only the Owner can invite another Admin.';
  }
  if (s.contains('EMAIL_INVALID') || s.contains('OWNER_EMAIL_INVALID')) {
    return 'Enter a valid email address.';
  }
  // INVITE_* codes from migration 010; bare EMAIL_MISMATCH covered by substring too.
  if (s.contains('EMAIL_MISMATCH')) {
    final invited = _inviteEmailFromError(raw);
    if (invited != null) {
      return 'Signed-in email doesn’t match this invite (sent to $invited). '
          'Sign out and use that email, or ask the owner for a new invite.';
    }
    return 'Signed-in email doesn’t match this invite. '
        'Ask your store owner to resend if you’re unsure which email was invited.';
  }
  if (s.contains('INVITE_EXPIRED') || s.contains('INVITE_INVALID_OR_EXPIRED')) {
    final invited = _inviteEmailFromError(raw);
    return invited != null
        ? 'This invite expired (was for $invited). Ask your store owner to resend it.'
        : 'This invite has expired. Ask your store owner to resend it.';
  }
  if (s.contains('ALREADY_ACCEPTED')) {
    return 'This invite was already accepted. Sign in with the invited email, '
        'or ask your store owner to send a new invite.';
  }
  if (s.contains('INVITE_NOT_PENDING')) {
    return 'This invite is no longer active. Ask your store owner to resend it.';
  }
  if (s.contains('INVITE_NOT_FOUND')) {
    return 'Invite not found. Check the link/token, or ask your store owner to resend it.';
  }
  if (s.contains('NOT_AUTHENTICATED') ||
      s.contains('SUPABASE IS NOT INITIALIZED') ||
      s.contains('NOT SIGNED IN')) {
    return 'Please sign in and try again.';
  }
  if (s.contains('STORE_NAME_REQUIRED')) {
    return 'Store name is required.';
  }
  if (s.contains('CANNOT_FRANCHISE_SELF')) {
    return 'You can’t open a franchise for your own email.';
  }
  if (s.contains('FRANCHISE_CANNOT_FRANCHISE')) {
    return 'Franchise stores can’t open another franchise.';
  }
  if (s.contains('STORE_NOT_FOUND')) {
    return 'Store not found.';
  }
  if (s.contains('STORE_SUSPENDED')) {
    return 'This store is suspended. Contact CasinPOS support.';
  }
  if (s.contains('FREE_TEAM_SEAT_LIMIT')) {
    return 'Free plan allows 2 people on this store (you + 1 teammate). Upgrade to Premium for more staff.';
  }
  if (s.contains('FREE_MONTHLY_LIMIT_REACHED')) {
    return 'Free monthly transaction limit reached (1,000 sales). Upgrade to Premium or ask CasinPOS support.';
  }
  if (s.contains('MEMBER_NOT_FOUND')) {
    return 'That teammate was already removed or isn’t on this store.';
  }
  if (s.contains('CANNOT_ASSIGN_OWNER')) {
    return 'Ownership can’t be assigned here. Contact CasinPOS support for owner transfer.';
  }
  if (s.contains('CANNOT_CHANGE_OWNER_ROLE')) {
    return 'You can’t change the Owner’s role.';
  }
  if (s.contains('CANNOT_CHANGE_OWN_ROLE')) {
    return 'You can’t change your own role.';
  }
  if (s.contains('CANNOT_REMOVE_OWNER')) {
    return 'You can’t remove the store Owner.';
  }
  if (s.contains('CANNOT_REMOVE_SELF')) {
    return 'You can’t remove yourself. Ask another Owner/Admin.';
  }
  if (s.contains('ADMIN_CANNOT_MANAGE_ADMIN')) {
    return 'Only the Owner can manage another Admin.';
  }
  if (s.contains('BRANCH_IDS_REQUIRED')) {
    return 'Pick at least one branch for Branch Manager.';
  }
  if (s.contains('BRANCH_IDS_INVALID')) {
    return 'That branch is invalid for this store.';
  }
  if (s.contains('PIN_NOT_SET')) {
    return 'This teammate has not set a cashier PIN yet. Set one under Team.';
  }
  if (s.contains('PIN_LOCKED')) {
    return 'Too many wrong PIN attempts. Wait a few minutes and try again.';
  }
  if (s.contains('PIN_INCORRECT')) {
    return 'Incorrect PIN.';
  }
  if (s.contains('SESSION_NOT_OPEN')) {
    return 'No open register session to claim.';
  }
  if (s.contains('INVALID LOGIN CREDENTIALS')) {
    return 'Wrong email or password.';
  }
  if (s.contains('EMAIL NOT CONFIRMED') || s.contains('EMAIL_NOT_CONFIRMED')) {
    return 'Confirm your email first (check inbox/spam), then sign in.';
  }
  if (s.contains('USER ALREADY REGISTERED')) {
    return 'That email is already registered. Sign in instead.';
  }
  return null;
}

/// Builds a searchable blob from common Supabase exception shapes.
String? _structuredErrorBlob(Object error) {
  try {
    final dynamic e = error;
    final parts = <String>[
      if (e.message != null) '${e.message}',
      if (e.code != null) '${e.code}',
      if (e.details != null) '${e.details}',
      if (e.hint != null) '${e.hint}',
      if (e.statusCode != null) '${e.statusCode}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  } catch (_) {
    return null;
  }
}

/// Parses `INVITE_*:email@x` detail suffixes from Postgres raise exception messages.
String? _inviteEmailFromError(String raw) {
  final m = RegExp(
    r'INVITE_[A-Z_]+[:\s]+([^\s,;]+@[^\s,;]+)',
    caseSensitive: false,
  ).firstMatch(raw);
  final email = m?.group(1)?.trim();
  if (email == null || !email.contains('@')) return null;
  return email.replaceAll(RegExp(r'[>\]\)]+$'), '');
}

void showAppError(
  BuildContext context,
  Object error, {
  String? fallback,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        friendlyError(
          error,
          fallback: fallback ?? 'Something went wrong. Please try again.',
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFE11D48),
      duration: const Duration(seconds: 4),
    ),
  );
}

void showAppMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFE11D48) : AppColors.slate900,
      duration: Duration(seconds: isError ? 4 : 2),
    ),
  );
}
