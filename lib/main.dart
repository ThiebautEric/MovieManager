import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'data/repositories/collection_repository.dart';
import 'l10n/gen/app_localizations.dart';
import 'widgets/tmdb_badge.dart';
import 'widgets/yellow_frame_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La clé TMDB est le minimum requis ; sinon on affiche un écran explicite.
  if (!AppConfig.isConfigured) {
    runApp(const _MisconfiguredApp());
    return;
  }

  // Splash Flutter pendant l'initialisation (remplace le splash natif incomplet).
  runApp(const _SplashApp());

  // Mode cloud (Supabase présent) : connexion + synchro.
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // La clé « anon public » reste valide ; `anonKey` est marqué déprécié au
      // profit de `publishableKey` mais accepte la même valeur.
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // SharedPreferences est toujours initialisé : utile en mode local (collection)
  // et dans les deux modes pour persister le choix de thème.
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MovieManagerApp(),
  ));
}

class MovieManagerApp extends ConsumerWidget {
  const MovieManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    // null = suivre la langue du système (résolue parmi supportedLocales).
    final locale = ref.watch(appLocaleProvider);
    return MaterialApp.router(
      title: 'The Yellow Frame',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}

/// Splash affiché pendant l'initialisation (Supabase + SharedPreferences).
/// Remplace le splash natif (icône seule) par le logo complet + badge TMDB.
class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TmdbBadge(height: 26),
              SizedBox(height: 20),
              YellowFrameLogo(width: 190),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran affiché quand les clés (`--dart-define`) sont absentes.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Yellow Frame',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key_off, size: 64),
                const SizedBox(height: 16),
                Text('Configuration manquante',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  'Clés absentes : ${AppConfig.missingKeys.join(', ')}.\n\n'
                  'Lancez l\'application avec --dart-define-from-file=dart_define.json '
                  '(voir le README).',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
