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

String friendlyError(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is AppException) return error.message;

  // Prefer structured Postgrest / Function fields when present (avoids raw dumps).
  final structured = _structuredErrorBlob(error);
  final raw = structured ?? error.toString();
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
      .replaceFirst(RegExp(r'^PostgresException:\s*'), '');
  final remapped = mapKnownBackendError(cleaned);
  if (remapped != null) return remapped;
  if (cleaned.trim().isEmpty) return fallback;
  // Never surface raw unique-constraint / Postgres noise.
  if (RegExp(r'23505|duplicate key value|store_invitations_pending_unique', caseSensitive: false)
      .hasMatch(cleaned)) {
    return 'That invite is already pending. Try again to resend the email.';
  }
  if (RegExp(
        r'PostgresException|PostgrestException|violates unique constraint|PGRST|severityException',
        caseSensitive: false,
      ).hasMatch(raw) ||
      RegExp(
        r'PostgresException|PostgrestException|violates unique constraint|PGRST',
        caseSensitive: false,
      ).hasMatch(cleaned)) {
    return fallback;
  }
  if (cleaned.length > 220) return '${cleaned.substring(0, 220)}…';
  return cleaned;
}

/// Maps known RPC / auth exception codes to short UI copy. Returns null if unknown.
String? mapKnownBackendError(String raw) {
  final s = raw.toUpperCase();
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
  if (s.contains('NOT_AUTHENTICATED')) {
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
    return 'Free monthly transaction limit reached (100 sales). Upgrade to Premium or ask CasinPOS support.';
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
      content: Text(friendlyError(error, fallback: fallback ?? 'Something went wrong. Please try again.')),
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
