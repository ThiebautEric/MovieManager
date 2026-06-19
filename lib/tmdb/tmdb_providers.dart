import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/genre.dart';
import 'models/media_details.dart';
import 'models/person_details.dart';
import 'tmdb_client.dart';

/// Client TMDB partagé.
final tmdbClientProvider = Provider<TmdbClient>((ref) => TmdbClient());

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
