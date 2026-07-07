import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/collection_entry.dart';
import '../../data/models/film.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';

/// Drapeau emoji à partir d'un code pays ISO-3166-1 alpha-2 (ex. « FR » → 🇫🇷).
String countryFlag(String iso) {
  if (iso.length != 2) return '';
  final up = iso.toUpperCase();
  final a = up.codeUnitAt(0), b = up.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '';
  return String.fromCharCodes([0x1F1E6 + (a - 65), 0x1F1E6 + (b - 65)]);
}

/// Libellé pays : drapeau + code (ex. « 🇫🇷 FR »).
String countryLabel(String iso) {
  final flag = countryFlag(iso);
  return flag.isEmpty ? iso : '$flag $iso';
}

/// Filtres communs aux deux vues (collection / historique). Les champs non
/// pertinents pour une vue sont simplement ignorés (ex. la note pour la
/// collection).
class CollectionFilter {
  const CollectionFilter({
    this.mediaType,
    this.genreId,
    this.country,
    this.year,
    this.minRating = 0,
    this.favoritePersonId,
  });

  final String? mediaType; // 'movie' | 'tv' | null (tous)
  final int? genreId;
  final String? country; // code ISO pays d'origine
  final int? year;
  final double minRating; // note minimale du visionnage (historique)
  final int? favoritePersonId; // id TMDB d'une personne favorite (casting)

  CollectionFilter copyWith({
    String? mediaType,
    bool clearMediaType = false,
    int? genreId,
    bool clearGenre = false,
    String? country,
    bool clearCountry = false,
    int? year,
    bool clearYear = false,
    double? minRating,
    int? favoritePersonId,
    bool clearFavorite = false,
  }) {
    return CollectionFilter(
      mediaType: clearMediaType ? null : (mediaType ?? this.mediaType),
      genreId: clearGenre ? null : (genreId ?? this.genreId),
      country: clearCountry ? null : (country ?? this.country),
      year: clearYear ? null : (year ?? this.year),
      minRating: minRating ?? this.minRating,
      favoritePersonId:
          clearFavorite ? null : (favoritePersonId ?? this.favoritePersonId),
    );
  }

  /// Critères portant sur le film (type, genre, pays, année, acteur favori).
  bool matchesFilm(Film f) {
    if (mediaType != null && f.mediaType != mediaType) return false;
    if (genreId != null && !f.genres.contains(genreId)) return false;
    if (country != null && f.originCountry != country) return false;
    if (year != null && f.releaseYear != year) return false;
    if (favoritePersonId != null && !f.castIds.contains(favoritePersonId)) {
      return false;
    }
    return true;
  }

  /// Visionnage : critères film + note minimale de la séance.
  bool matchesHistory(HistoryView v) {
    if (!matchesFilm(v.film)) return false;
    if (minRating > 0 && (v.rating ?? 0) < minRating) return false;
    return true;
  }

  bool get isActive =>
      mediaType != null ||
      genreId != null ||
      country != null ||
      year != null ||
      minRating > 0 ||
      favoritePersonId != null;
}

/// Filtre de l'onglet Historique (indépendant de la collection).
final historyFilterProvider =
    StateProvider<CollectionFilter>((ref) => const CollectionFilter());

/// Filtre de l'onglet Collection (indépendant de l'historique).
final collectionFilterProvider =
    StateProvider<CollectionFilter>((ref) => const CollectionFilter());

/// Historique filtré, du plus récent au plus ancien.
final filteredHistoryProvider = Provider<List<HistoryView>>((ref) {
  final all = ref.watch(historyStreamProvider).value ?? [];
  final filter = ref.watch(historyFilterProvider);
  return all.where(filter.matchesHistory).toList();
});

/// Collection filtrée (tous supports).
final filteredCollectionProvider = Provider<List<CollectionView>>((ref) {
  final all = ref.watch(collectionStreamProvider).value ?? [];
  final filter = ref.watch(collectionFilterProvider);
  return all.where((c) => filter.matchesFilm(c.film)).toList();
});
