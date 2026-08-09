import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/invite/pending_invite_token.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Path URLs so email invite links work: /invite?token=… (needs Vercel SPA rewrite).
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  // Persist ?token= before go_router redirects (intro) can drop the query string.
  captureInviteTokenFromUri(Uri.base);
  await bootstrap();
  runApp(const ProviderScope(child: CasinPosApp()));
}
