import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/touch_targets.dart';
import '../../data/providers/session_providers.dart';

/// Re-enter the signed-in user's password (manager / destructive confirms).
///
/// The password dialog is always closed **before** `signInWithPassword` runs.
/// Calling auth while a route is still mounted rebuilds providers/shell under
/// open dialogs and triggers InheritedWidget `_dependents.isEmpty` asserts.
Future<bool> confirmSignedInPassword(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String body,
  String confirmLabel = 'Confirm',
}) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  final email = user?.email?.trim();
  if (email == null || email.isEmpty) {
    showAppMessage(
      context,
      'No signed-in email found. Sign in again, then retry.',
      isError: true,
    );
    return false;
  }

  while (context.mounted) {
    final password = await _promptPassword(
      context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
    );
    if (password == null) return false;
    if (!context.mounted) return false;

    // Let the dialog route fully unmount before auth notifies listeners.
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return false;

    final ok = await _verifyPassword(ref, email, password);
    if (ok) return true;
    if (!context.mounted) return false;
    showAppMessage(context, 'Incorrect password', isError: true);
  }
  return false;
}

Future<String?> _promptPassword(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final passwordCtrl = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var obscure = true;
        var submitting = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  body,
                  style: const TextStyle(fontSize: 13, color: AppColors.slate600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  autofocus: true,
                  enabled: !submitting,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setLocal(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  onSubmitted: submitting
                      ? null
                      : (_) {
                          final value = passwordCtrl.text;
                          if (value.isEmpty) return;
                          setLocal(() => submitting = true);
                          Navigator.pop(ctx, value);
                        },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                style: TextButton.styleFrom(minimumSize: TouchTargets.buttonMin),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () {
                        final value = passwordCtrl.text;
                        if (value.isEmpty) return;
                        setLocal(() => submitting = true);
                        Navigator.pop(ctx, value);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white,
                  minimumSize: TouchTargets.buttonMin,
                  padding: TouchTargets.buttonPadding,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    // Dispose after the dialog future settles (route unmounted).
    passwordCtrl.dispose();
  }
}

Future<bool> _verifyPassword(WidgetRef ref, String email, String password) async {
  if (password.isEmpty) return false;
  try {
    await ref.read(authRepositoryProvider).signIn(email: email, password: password);
    return true;
  } catch (_) {
    return false;
  }
}
