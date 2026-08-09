import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes platform services. Supabase is optional until env is set.
Future<void> bootstrap() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (url.isEmpty || anonKey.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'CasinPOS: SUPABASE_URL / SUPABASE_ANON_KEY not set — '
        'running UI scaffold without backend. '
        'Pass via --dart-define when ready.',
      );
    }
    return;
  }

  // publishableKey is the current Supabase Flutter API name for the anon key.
  await Supabase.initialize(url: url, publishableKey: anonKey);
}

bool get isSupabaseReady {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  return url.isNotEmpty && anonKey.isNotEmpty;
}

SupabaseClient? get supabaseOrNull =>
    isSupabaseReady ? Supabase.instance.client : null;
