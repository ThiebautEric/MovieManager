/// Configuration de l'application.
///
/// Toutes les clés sont injectées au build via `--dart-define` (ou
/// `--dart-define-from-file=dart_define.json`). Aucune clé n'est stockée en
/// dur dans le code source.
class AppConfig {
  const AppConfig._();

  /// Token TMDB (v4 « Bearer »). Obtenu sur https://www.themoviedb.org/settings/api
  static const String tmdbToken = String.fromEnvironment('TMDB_TOKEN');

  /// URL du projet Supabase (Project Settings > API).
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Clé publique « anon » du projet Supabase.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Clé Google Cloud Vision API (OCR jaquette, feature photo-recherche).
  /// Injectée au build (comme les autres clés) — aucune valeur en dur.
  /// ⚠️ Clé appelée côté client : elle DOIT être restreinte côté GCP
  /// (referrer HTTP + API Vision uniquement + quota), car elle est
  /// nécessairement présente dans le bundle livré.
  static const String visionApiKey = String.fromEnvironment('VISION_API_KEY');

  /// Vrai si la fonctionnalité de recherche par photo est disponible.
  static bool get hasVisionApi => visionApiKey.isNotEmpty;

  /// La clé TMDB est le minimum requis pour faire tourner l'app.
  static bool get hasTmdb => tmdbToken.isNotEmpty;

  /// Supabase est optionnel : présent → mode cloud (connexion + synchro),
  /// absent → mode local (stockage sur l'appareil, sans compte).
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Vrai si l'app peut démarrer (au minimum la clé TMDB).
  static bool get isConfigured => hasTmdb;

  /// Clés manquantes bloquantes (uniquement TMDB ici).
  static List<String> get missingKeys => [
        if (tmdbToken.isEmpty) 'TMDB_TOKEN',
      ];
}
