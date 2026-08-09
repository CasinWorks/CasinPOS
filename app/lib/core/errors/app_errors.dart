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

  final raw = error.toString();
  final mapped = mapKnownBackendError(raw);
  if (mapped != null) return mapped;

  // Strip noisy Exception: prefixes from Supabase / Dart.
  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^StateError:\s*'), '')
      .replaceFirst(RegExp(r'^Bad state:\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException\([^)]*\):\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException:\s*'), '');
  if (cleaned.trim().isEmpty) return fallback;
  // Never surface raw unique-constraint / Postgres noise.
  if (RegExp(r'23505|duplicate key value|store_invitations_pending_unique', caseSensitive: false)
      .hasMatch(cleaned)) {
    return 'That invite is already pending. Try again to resend the email.';
  }
  if (RegExp(r'PostgresException|violates unique constraint|PGRST', caseSensitive: false)
      .hasMatch(cleaned)) {
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
  if (s.contains('INVITE_EMAIL_MISMATCH')) {
    return 'Signed-in email doesn’t match this invite.';
  }
  if (s.contains('INVITE_INVALID_OR_EXPIRED')) {
    return 'Invite is invalid or expired.';
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
  if (s.contains('FREE_MONTHLY_LIMIT_REACHED')) {
    return 'Free monthly transaction limit reached.';
  }
  return null;
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
