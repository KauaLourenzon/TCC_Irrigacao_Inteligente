abstract final class Environment {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const aiApiBaseUrl = String.fromEnvironment('AI_API_BASE_URL');
}
