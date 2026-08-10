import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap.dart';
import 'core/animations/fluid_ink_intro.dart';
import 'core/invite/invite_token.dart';
import 'core/invite/pending_invite_token.dart';
import 'data/providers/session_providers.dart';
import 'features/auth/login_page.dart';
import 'features/customer_display/customer_display_page.dart';
import 'features/onboarding/create_store_page.dart';
import 'features/shell/pos_shell_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/intro',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final introSeen = ref.read(introSeenProvider);

      // Always capture invite token from the current URI before any redirect
      // (intro previously dropped /invite?token=… before the join page ran).
      captureInviteTokenFromUri(state.uri);
      final pathTok = state.pathParameters['token'];
      if (pathTok != null && pathTok.isNotEmpty) {
        savePendingInviteToken(pathTok);
      }

      if (!introSeen && loc != '/intro' && loc != '/display') {
        return '/intro';
      }
      if (loc == '/intro') {
        return introSeen ? _postIntroTarget(ref) : null;
      }

      if (!isSupabaseReady) {
        // Offline / UI scaffold: allow login & signup so Sign out works.
        // Demo entry stays on `/` via intro / "Continue to demo".
        return null;
      }

      final session = ref.read(currentSessionProvider);
      final membershipsAsync = ref.read(membershipsProvider);
      final loggingIn = loc == '/login' || loc == '/signup';
      final onInvite = loc == '/invite' || loc == '/join' || loc.startsWith('/invite/');
      final onboarding = loc == '/onboarding/store';
      final onCustomerDisplay = loc == '/display';
      final pendingToken = readPendingInviteToken();
      final hasPendingInvite = pendingToken != null && pendingToken.isNotEmpty;

      if (session == null) {
        if (loggingIn || onInvite) return null;
        return '/login';
      }

      if (membershipsAsync.isLoading) {
        if (loggingIn) return '/';
        return null;
      }

      final memberships = membershipsAsync.valueOrNull ?? [];
      final hasStore = memberships.isNotEmpty;

      if (!hasStore) {
        if (onCustomerDisplay) return null;
        if (onboarding || onInvite) return null;
        if (hasPendingInvite) {
          return '/invite?token=${Uri.encodeQueryComponent(pendingToken)}';
        }
        if (loggingIn) return '/onboarding/store';
        return '/onboarding/store';
      }

      if (onCustomerDisplay) return null;

      if (loggingIn || onboarding) {
        if (hasPendingInvite && !onInvite) {
          return '/invite?token=${Uri.encodeQueryComponent(pendingToken)}';
        }
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/intro',
        builder: (context, state) => FluidInkIntro(
          onComplete: () {
            ref.read(introSeenProvider.notifier).state = true;
            context.go(_postIntroTarget(ref));
          },
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
      GoRoute(
        path: '/invite',
        builder: (context, state) => InviteAcceptPage(
          initialToken: sanitizeInviteToken(state.uri.queryParameters['token']),
        ),
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => InviteAcceptPage(
          initialToken: sanitizeInviteToken(state.uri.queryParameters['token']),
        ),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) => InviteAcceptPage(
          initialToken: sanitizeInviteToken(state.pathParameters['token']),
        ),
      ),
      GoRoute(
        path: '/onboarding/store',
        builder: (context, state) => const CreateStorePage(),
      ),
      GoRoute(
        path: '/display',
        builder: (context, state) => const CustomerDisplayPage(),
      ),
      GoRoute(path: '/', builder: (context, state) => const PosShellPage()),
    ],
  );
});

String _postIntroTarget(Ref ref) {
  if (!isSupabaseReady) return '/';
  final pending = readPendingInviteToken();
  if (pending != null && pending.isNotEmpty) {
    return '/invite?token=${Uri.encodeQueryComponent(pending)}';
  }
  final session = ref.read(currentSessionProvider);
  if (session == null) return '/login';
  final memberships = ref.read(membershipsProvider).valueOrNull;
  if (memberships == null) return '/';
  if (memberships.isEmpty) return '/onboarding/store';
  return '/';
}

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    // User id only — password re-auth must not rebuild routes under open dialogs.
    ref.listen(authUserIdProvider, (_, _) => notifyListeners());
    ref.listen(membershipsProvider, (_, _) => notifyListeners());
    ref.listen(introSeenProvider, (_, _) => notifyListeners());
  }

  final Ref ref;
}
