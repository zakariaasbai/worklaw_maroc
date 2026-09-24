/// Reads Supabase configuration compiled in via
/// `--dart-define-from-file=env.json` (see DATABASE.md).
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY are not set. Run with '
        '--dart-define-from-file=env.json (see DATABASE.md).',
      );
    }
  }
}
