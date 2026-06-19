import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/collection_item.dart';
import '../../data/repositories/collection_repository.dart';

enum WatchedFilter { all, watched, unwatched }

/// État des filtres appliqués à la collection.
class CollectionFilter {
  const CollectionFilter({
    this.mediaType,
    this.genreId,
    this.year,
    this.minRating = 0,
    this.watched = WatchedFilter.all,
    this.ownedOnly = false,
  });

  final String? mediaType; // 'movie' | 'tv' | null (tous)
  final int? genreId;
  final int? year;
  final double minRating;
  final WatchedFilter watched;
  final bool ownedOnly;

  CollectionFilter copyWith({
    String? mediaType,
    bool clearMediaType = false,
    int? genreId,
    bool clearGenre = false,
    int? year,
    bool clearYear = false,
    double? minRating,
    WatchedFilter? watched,
    bool? ownedOnly,
  }) {
    return CollectionFilter(
      mediaType: clearMediaType ? null : (mediaType ?? this.mediaType),
      genreId: clearGenre ? null : (genreId ?? this.genreId),
      year: clearYear ? null : (year ?? this.year),
      minRating: minRating ?? this.minRating,
      watched: watched ?? this.watched,
      ownedOnly: ownedOnly ?? this.ownedOnly,
    );
  }

  bool matches(CollectionItem item) {
    if (mediaType != null && item.mediaType != mediaType) return false;
    if (genreId != null && !item.genres.contains(genreId)) return false;
    if (year != null && item.releaseYear != year) return false;
    if (minRating > 0 && (item.userRating ?? 0) < minRating) return false;
    if (watched == WatchedFilter.watched && !item.watched) return false;
    if (watched == WatchedFilter.unwatched && item.watched) return false;
    if (ownedOnly && !item.owned) return false;
    return true;
  }

  bool get isActive =>
      mediaType != null ||
      genreId != null ||
      year != null ||
      minRating > 0 ||
      watched != WatchedFilter.all ||
      ownedOnly;
}

final collectionFilterProvider =
    StateProvider<CollectionFilter>((ref) => const CollectionFilter());

/// Collection filtrée selon les filtres courants.
final filteredCollectionProvider = Provider<List<CollectionItem>>((ref) {
  final all = ref.watch(collectionStreamProvider).value ?? [];
  final filter = ref.watch(collectionFilterProvider);
  return all.where(filter.matches).toList();
});
