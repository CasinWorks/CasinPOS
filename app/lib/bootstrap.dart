import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _looksLikeSupabaseConfig(String url, String anonKey) {
  if (url.isEmpty || anonKey.isEmpty) return false;
  final u = url.trim();
  final k = anonKey.trim();
  // Vercel `env pull` redacts secrets as the literal "[SENSITIVE]".
  if (u.contains('SENSITIVE') ||
      k.contains('SENSITIVE') ||
      u.contains('YOUR_PROJECT') ||
      k == 'your-anon-key' ||
      k.length < 20) {
    return false;
  }
  return u.startsWith('https://') && u.contains('supabase.co');
}

/// Initializes platform services. Supabase is optional until env is set.
Future<void> bootstrap() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (!_looksLikeSupabaseConfig(url, anonKey)) {
    if (kDebugMode) {
      debugPrint(
        'CasinPOS: SUPABASE_URL / SUPABASE_ANON_KEY missing or invalid — '
        'running UI scaffold without backend. '
        'Use a real .env (not Vercel [SENSITIVE] placeholders) via '
        '--dart-define-from-file / --dart-define.',
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
  return _looksLikeSupabaseConfig(url, anonKey);
}

SupabaseClient? get supabaseOrNull =>
    isSupabaseReady ? Supabase.instance.client : null;
