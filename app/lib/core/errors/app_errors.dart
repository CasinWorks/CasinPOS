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
  // Strip noisy Exception: prefixes from Supabase / Dart.
  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^StateError:\s*'), '')
      .replaceFirst(RegExp(r'^Bad state:\s*'), '');
  if (cleaned.trim().isEmpty) return fallback;
  if (cleaned.length > 220) return '${cleaned.substring(0, 220)}…';
  return cleaned;
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
