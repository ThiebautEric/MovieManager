import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/collection_repository.dart'
    show sharedPreferencesProvider;

/// Langue choisie par l'utilisateur (null = suivre le système), persistée
/// localement — même mécanique que le thème.
class AppLocaleController extends Notifier<Locale?> {
  static const _key = 'app_locale';
  static const supported = [Locale('fr'), Locale('de'), Locale('en')];

  @override
  Locale? build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_key);
    for (final l in supported) {
      if (l.languageCode == code) return l;
    }
    return null;
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}

final appLocaleProvider =
    NotifierProvider<AppLocaleController, Locale?>(AppLocaleController.new);

/// Locale réellement affichée : le choix utilisateur, sinon la langue du
/// système si elle est supportée, sinon le français.
final effectiveLocaleProvider = Provider<Locale>((ref) {
  final chosen = ref.watch(appLocaleProvider);
  if (chosen != null) return chosen;
  final sys = PlatformDispatcher.instance.locale;
  return AppLocaleController.supported.firstWhere(
    (l) => l.languageCode == sys.languageCode,
    orElse: () => const Locale('fr'),
  );
});

/// Code langue TMDB (métadonnées : titres localisés, synopsis…) aligné sur la
/// locale effective de l'application.
final tmdbLanguageProvider = Provider<String>(
  (ref) => switch (ref.watch(effectiveLocaleProvider).languageCode) {
    'de' => 'de-DE',
    'en' => 'en-US',
    _ => 'fr-FR',
  },
);
