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

/// Titre à afficher selon le mode courant. Les titres traduit et anglais ne
/// sont pas fiables/présents en base (imports stockés en anglais…) : ils sont
/// récupérés à la demande via TMDB et mis en cache pour la session ; en
/// attendant (ou à défaut), repli sur le titre fourni / original.
///
/// [titleIsLocalized] : vrai quand [title] vient déjà de l'API TMDB dans la
/// langue de l'appli (recherche, fiche détail, filmographie) — on évite alors
/// une requête. Faux pour les titres stockés en base (historique, collection).
String resolveTitle(
  WidgetRef ref, {
  required int tmdbId,
  required String mediaType,
  required String title,
  String? originalTitle,
  bool titleIsLocalized = false,
}) {
  final original =
      (originalTitle != null && originalTitle.isNotEmpty) ? originalTitle : title;
  return switch (ref.watch(titleDisplayModeProvider)) {
    TitleDisplayMode.localized => titleIsLocalized
        ? title
        : ref
                .watch(localizedTitleProvider((id: tmdbId, type: mediaType)))
                .value ??
            title,
    TitleDisplayMode.original => original,
    TitleDisplayMode.english =>
      ref.watch(englishTitleProvider((id: tmdbId, type: mediaType))).value ??
          original,
  };
}
