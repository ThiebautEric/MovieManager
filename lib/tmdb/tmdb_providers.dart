import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/locale_controller.dart';
import 'models/genre.dart';
import 'models/media_details.dart';
import 'models/person_details.dart';
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

/// Détails d'un média, mis en cache par (tmdbId, mediaType).
final mediaDetailsProvider = FutureProvider.family<MediaDetails, ({int id, String type})>(
  (ref, key) {
    return ref.watch(tmdbClientProvider).details(key.id, key.type);
  },
);

/// Fiche détaillée d'une personne (acteur), mise en cache par id.
final personDetailsProvider =
    FutureProvider.family<PersonDetails, int>((ref, personId) {
  return ref.watch(tmdbClientProvider).person(personId);
});

/// Liste des genres TMDB (chargée une fois), indexée par id pour l'affichage.
final genresProvider = FutureProvider<List<Genre>>((ref) {
  return ref.watch(tmdbClientProvider).genres();
});

/// Map id -> nom de genre (pratique pour les filtres et l'affichage).
final genresByIdProvider = Provider<Map<int, String>>((ref) {
  final genres = ref.watch(genresProvider).value ?? [];
  return {for (final g in genres) g.id: g.name};
});
