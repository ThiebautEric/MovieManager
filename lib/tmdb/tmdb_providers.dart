import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/locale_controller.dart';
import 'models/genre.dart';
import 'models/media_details.dart';
import 'models/person_details.dart';
import 'models/season_episodes.dart';
import 'models/tmdb_collection.dart';
import 'tmdb_client.dart';

/// Client TMDB partagé. Suit la langue de l'application : en changer
/// invalide le client et donc tous les caches (détails, genres…).
final tmdbClientProvider = Provider<TmdbClient>(
    (ref) => TmdbClient(language: ref.watch(tmdbLanguageProvider)));

/// Client TMDB dédié aux titres anglais (mode « EN » du bouton titres).
final _tmdbEnClientProvider =
    Provider<TmdbClient>((ref) => TmdbClient(language: 'en-US'));

/// Titre anglais d'un média, récupéré à la demande (mode « titres anglais »)
/// et conservé en cache pour la session.
final englishTitleProvider =
    FutureProvider.family<String?, ({int id, String type})>((ref, key) {
  ref.keepAlive();
  return ref.watch(_tmdbEnClientProvider).title(key.id, key.type);
});

/// Titre dans la langue de l'appli, récupéré à la demande et mis en cache.
/// Utile pour les titres stockés en base dans une autre langue (imports…) ;
/// changer la langue de l'appli invalide le cache (le client est recréé).
final localizedTitleProvider =
    FutureProvider.family<String?, ({int id, String type})>((ref, key) {
  ref.keepAlive();
  return ref.watch(tmdbClientProvider).title(key.id, key.type);
});

/// Affiche d'un média dans sa langue d'origine (résultats de recherche).
/// Interroge `/images` (non localisé) et retient l'affiche de la langue de
/// sortie du film. Mise en cache par média pour la session.
final originalPosterProvider =
    FutureProvider.family<String?, ({int id, String type, String? lang})>(
  (ref, key) {
    ref.keepAlive();
    return ref
        .watch(tmdbClientProvider)
        .originalPoster(key.id, key.type, key.lang);
  },
);

/// Détails d'un média, mis en cache par (tmdbId, mediaType).
/// keepAlive : évite l'autoDispose entre les rebuilds du screen (comme les
/// autres providers TMDB) ; invalidé automatiquement si la langue change.
final mediaDetailsProvider = FutureProvider.family<MediaDetails, ({int id, String type})>(
  (ref, key) {
    ref.keepAlive();
    return ref.watch(tmdbClientProvider).details(key.id, key.type);
  },
);

/// Numéros de saisons (hors saison 0) d'une série, déduits de [mediaDetailsProvider].
/// Retourne `{}` tant que les détails ne sont pas chargés — sans requête supplémentaire.
final seasonsTmdbProvider =
    Provider.family<Set<int>, ({int id, String type})>((ref, key) {
  ref.keepAlive();
  final details = ref.watch(mediaDetailsProvider(key)).value;
  if (details == null) return const {};
  return {
    for (final s in details.seasons)
      if (s.seasonNumber > 0) s.seasonNumber,
  };
});

/// Collection TMDB (saga) complète avec ses films, mise en cache par id.
final collectionProvider = FutureProvider.family<TmdbCollection, int>((ref, id) {
  ref.keepAlive();
  return ref.watch(tmdbClientProvider).collection(id);
});

/// Recherche de collections (sagas) par nom — autoDispose comme la recherche
/// multi (résultat éphémère, dépend de la requête courante).
final searchCollectionsProvider =
    FutureProvider.autoDispose.family<List<CollectionRef>, String>((ref, query) {
  final q = query.trim();
  if (q.isEmpty) return Future.value(const <CollectionRef>[]);
  return ref.watch(tmdbClientProvider).searchCollections(q);
});

/// Fiche détaillée d'une personne (acteur), mise en cache par id.
final personDetailsProvider =
    FutureProvider.family<PersonDetails, int>((ref, personId) {
  ref.keepAlive();
  return ref.watch(tmdbClientProvider).person(personId);
});

/// Épisodes d'une saison, mis en cache par (série, saison) — notation par
/// épisode sur la fiche détail et noms d'épisodes localisés.
final seasonEpisodesProvider =
    FutureProvider.family<List<EpisodeInfo>, ({int id, int season})>(
  (ref, key) {
    ref.keepAlive();
    return ref.watch(tmdbClientProvider).seasonEpisodes(key.id, key.season);
  },
);

/// Épisodes d'une saison en anglais — noms d'épisodes des modes VO/EN.
final englishSeasonEpisodesProvider =
    FutureProvider.family<List<EpisodeInfo>, ({int id, int season})>(
  (ref, key) {
    ref.keepAlive();
    return ref.watch(_tmdbEnClientProvider).seasonEpisodes(key.id, key.season);
  },
);

/// Runtime exact d'un épisode individuel — endpoint `/season/{n}/episode/{m}`.
/// Utilisé en fallback quand l'endpoint saison ne retourne pas de runtime
/// (fréquent pour saison 0 / spéciaux de séries britanniques).
final episodeRuntimeProvider =
    FutureProvider.family<int?, ({int id, int season, int episode})>(
  (ref, key) {
    ref.keepAlive();
    return ref
        .watch(tmdbClientProvider)
        .episodeRuntime(key.id, key.season, key.episode);
  },
);

/// Casting d'une saison TV — endpoint `/tv/{id}/season/{n}/credits`.
final seasonCastProvider =
    FutureProvider.family<List<CastMember>, ({int id, int season})>(
  (ref, key) {
    ref.keepAlive();
    return ref.watch(tmdbClientProvider).seasonCast(key.id, key.season);
  },
);

/// Casting d'un épisode — endpoint `/tv/{id}/season/{n}/episode/{e}/credits`.
final episodeCastProvider =
    FutureProvider.family<List<CastMember>, ({int id, int season, int episode})>(
  (ref, key) {
    ref.keepAlive();
    return ref
        .watch(tmdbClientProvider)
        .episodeCast(key.id, key.season, key.episode);
  },
);

/// Liste des genres TMDB (chargée une fois), indexée par id pour l'affichage.
final genresProvider = FutureProvider<List<Genre>>((ref) {
  ref.keepAlive();
  return ref.watch(tmdbClientProvider).genres();
});

/// Map id -> nom de genre (pratique pour les filtres et l'affichage).
final genresByIdProvider = Provider<Map<int, String>>((ref) {
  final genres = ref.watch(genresProvider).value ?? [];
  return {for (final g in genres) g.id: g.name};
});
