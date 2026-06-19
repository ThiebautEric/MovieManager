import '../../tmdb/models/media_details.dart';
import '../../tmdb/models/media_summary.dart';

/// Un item de la collection de l'utilisateur (mappé sur la table
/// `collection_items` de Supabase).
class CollectionItem {
  CollectionItem({
    this.id,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.releaseYear,
    this.genres = const [],
    this.owned = false,
    this.userRating,
    this.notes,
    this.addedAt,
    this.ownedAt,
    List<DateTime> watchDates = const [],
  }) : watchDates = _sortedDesc(watchDates);

  final String? id; // null avant insertion (généré par Supabase)
  final int tmdbId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final int? releaseYear;
  final List<int> genres;
  final bool owned;
  final double? userRating;
  final String? notes;
  final DateTime? addedAt;

  /// Date de mise en possession (acquisition).
  final DateTime? ownedAt;

  /// Dates de visionnage (un film peut être vu plusieurs fois), triées du plus
  /// récent au plus ancien.
  final List<DateTime> watchDates;

  /// Vu = au moins un visionnage enregistré.
  bool get watched => watchDates.isNotEmpty;

  /// Date du dernier visionnage (le plus récent), ou null.
  DateTime? get lastWatchedAt => watchDates.isEmpty ? null : watchDates.first;

  static List<DateTime> _sortedDesc(List<DateTime> dates) {
    final copy = [...dates]..sort((a, b) => b.compareTo(a));
    return List.unmodifiable(copy);
  }

  CollectionItem copyWith({
    bool? owned,
    double? userRating,
    bool clearRating = false,
    String? notes,
    DateTime? ownedAt,
    bool clearOwnedAt = false,
    List<DateTime>? watchDates,
  }) {
    return CollectionItem(
      id: id,
      tmdbId: tmdbId,
      mediaType: mediaType,
      title: title,
      posterPath: posterPath,
      releaseYear: releaseYear,
      genres: genres,
      owned: owned ?? this.owned,
      userRating: clearRating ? null : (userRating ?? this.userRating),
      notes: notes ?? this.notes,
      addedAt: addedAt,
      ownedAt: clearOwnedAt ? null : (ownedAt ?? this.ownedAt),
      watchDates: watchDates ?? this.watchDates,
    );
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    // Dates de visionnage : nouvelle liste, avec migration depuis l'ancien
    // champ unique `watched_at` si nécessaire.
    var watchDates = (json['watch_dates'] as List<dynamic>? ?? [])
        .map((e) => DateTime.tryParse(e as String))
        .whereType<DateTime>()
        .toList();
    if (watchDates.isEmpty &&
        (json['watched'] as bool? ?? false) &&
        json['watched_at'] != null) {
      final legacy = DateTime.tryParse(json['watched_at'] as String);
      if (legacy != null) watchDates = [legacy];
    }

    return CollectionItem(
      id: json['id'] as String?,
      tmdbId: json['tmdb_id'] as int,
      mediaType: json['media_type'] as String,
      title: (json['title'] as String?) ?? 'Sans titre',
      posterPath: json['poster_path'] as String?,
      releaseYear: json['release_year'] as int?,
      genres:
          (json['genres'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
      owned: (json['owned'] as bool?) ?? false,
      userRating: (json['user_rating'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      addedAt: json['added_at'] != null
          ? DateTime.tryParse(json['added_at'] as String)
          : null,
      ownedAt: json['owned_at'] != null
          ? DateTime.tryParse(json['owned_at'] as String)
          : null,
      watchDates: watchDates,
    );
  }

  /// Payload pour insert/update (sans `id`, `user_id` injecté par le repository).
  /// `watched` est dérivé des dates de visionnage. On n'écrit plus `watched_at`
  /// (redondant avec `watch_dates`) ; il n'est lu que pour migrer l'ancien format.
  Map<String, dynamic> toUpsertJson() => {
        'tmdb_id': tmdbId,
        'media_type': mediaType,
        'title': title,
        'poster_path': posterPath,
        'release_year': releaseYear,
        'genres': genres,
        'owned': owned,
        'owned_at': ownedAt?.toIso8601String(),
        'watched': watched,
        'watch_dates': watchDates.map((d) => d.toIso8601String()).toList(),
        'user_rating': userRating,
        'notes': notes,
      };

  /// JSON complet (avec `id` et `added_at`) pour la persistance locale.
  Map<String, dynamic> toFullJson() => {
        'id': id,
        'added_at': (addedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .toIso8601String(),
        ...toUpsertJson(),
      };

  /// Crée un item « possédé non vu » à partir d'un résultat de recherche.
  factory CollectionItem.fromSummary(MediaSummary s) => CollectionItem(
        tmdbId: s.tmdbId,
        mediaType: s.mediaType,
        title: s.title,
        posterPath: s.posterPath,
        releaseYear: s.releaseYear,
        genres: s.genreIds,
      );

  /// Crée un item à partir d'une fiche détaillée.
  factory CollectionItem.fromDetails(MediaDetails d) => CollectionItem(
        tmdbId: d.tmdbId,
        mediaType: d.mediaType,
        title: d.title,
        posterPath: d.posterPath,
        releaseYear: d.releaseYear,
        genres: d.genreIds,
      );
}
