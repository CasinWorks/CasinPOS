import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/session_providers.dart';
import 'data/providers/ui_prefs_providers.dart';

class CasinPosApp extends ConsumerWidget {
  const CasinPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final textScale = ref.watch(appTextScaleProvider);

    ref.listen(authStateProvider, (prev, next) {
      final state = next.valueOrNull;
      if (state?.event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryPendingProvider.notifier).state = true;
      }
    });

    ref.listen(passwordRecoveryPendingProvider, (prev, next) {
      if (next == true) {
        router.go('/reset-password');
      }
    });

    return MaterialApp.router(
      title: 'CasinPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final systemFactor = mq.textScaler.scale(1);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(systemFactor * textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
