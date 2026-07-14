import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/collection_repository.dart'
    show sharedPreferencesProvider;
import '../../tmdb/tmdb_providers.dart';

/// Mode d'affichage des titres : traduit (langue de l'appli), original (VO),
/// ou anglais. Le bouton d'AppBar fait défiler les trois modes.
enum TitleDisplayMode { localized, original, english }

/// Préférence persistée localement, comme le thème.
class TitleDisplayController extends Notifier<TitleDisplayMode> {
  static const _key = 'title_display_mode';

  @override
  TitleDisplayMode build() {
    final v = ref.watch(sharedPreferencesProvider).getString(_key);
    return TitleDisplayMode.values.asNameMap()[v] ?? TitleDisplayMode.localized;
  }

  /// Passe au mode suivant : traduit → original → anglais → traduit…
  Future<void> cycle() async {
    final next = TitleDisplayMode
        .values[(state.index + 1) % TitleDisplayMode.values.length];
    state = next;
    await ref.read(sharedPreferencesProvider).setString(_key, next.name);
  }
}

final titleDisplayModeProvider =
    NotifierProvider<TitleDisplayController, TitleDisplayMode>(
        TitleDisplayController.new);

/// Titre à afficher selon le mode courant. Le titre anglais n'est pas stocké
/// en base : il est récupéré à la demande via TMDB (en-US) et mis en cache ;
/// en attendant (ou à défaut), repli sur le titre original puis le titre
/// traduit.
String resolveTitle(
  WidgetRef ref, {
  required int tmdbId,
  required String mediaType,
  required String title,
  String? originalTitle,
}) {
  final original =
      (originalTitle != null && originalTitle.isNotEmpty) ? originalTitle : title;
  return switch (ref.watch(titleDisplayModeProvider)) {
    TitleDisplayMode.localized => title,
    TitleDisplayMode.original => original,
    TitleDisplayMode.english =>
      ref.watch(englishTitleProvider((id: tmdbId, type: mediaType))).value ??
          original,
  };
}
