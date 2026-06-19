/// Résultat de recherche TMDB : un film ou une série, version résumée.
class MediaSummary {
  const MediaSummary({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.genreIds,
  });

  final int tmdbId;
  final String mediaType; // 'movie' | 'tv'
  final String title;
  final String overview;
  final String? posterPath;
  final String? releaseDate; // 'YYYY-MM-DD'
  final double voteAverage;
  final List<int> genreIds;

  int? get releaseYear {
    if (releaseDate == null || releaseDate!.length < 4) return null;
    return int.tryParse(releaseDate!.substring(0, 4));
  }

  /// Construit depuis un item de `/search/multi` (movie/tv). Renvoie null pour
  /// les autres types (ex. `person`).
  static MediaSummary? fromJson(Map<String, dynamic> json) {
    final type = json['media_type'] as String?;
    return fromJsonAs(json, type);
  }

  /// Variante utilisée quand le type n'est pas dans le JSON (ex. résultats de
  /// `/search/movie` où le type est implicite).
  static MediaSummary? fromJsonAs(Map<String, dynamic> json, String? type) {
    if (type != 'movie' && type != 'tv') return null;
    final isMovie = type == 'movie';
    return MediaSummary(
      tmdbId: json['id'] as int,
      mediaType: type!,
      title: (isMovie ? json['title'] : json['name']) as String? ?? 'Sans titre',
      overview: (json['overview'] as String?) ?? '',
      posterPath: json['poster_path'] as String?,
      releaseDate:
          (isMovie ? json['release_date'] : json['first_air_date']) as String?,
      voteAverage: ((json['vote_average'] as num?) ?? 0).toDouble(),
      genreIds: (json['genre_ids'] as List<dynamic>? ?? [])
          .map((e) => e as int)
          .toList(),
    );
  }
}
