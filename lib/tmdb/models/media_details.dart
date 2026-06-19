import 'genre.dart';

/// Membre du casting (acteur principal).
class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    required this.profilePath,
  });

  final int id; // identifiant TMDB de la personne
  final String name;
  final String character;
  final String? profilePath;

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
        id: (json['id'] as int?) ?? 0,
        name: (json['name'] as String?) ?? '',
        character: (json['character'] as String?) ?? '',
        profilePath: json['profile_path'] as String?,
      );
}

/// Vidéo associée (bande-annonce YouTube, etc.).
class Video {
  const Video({
    required this.name,
    required this.key,
    required this.site,
    required this.type,
  });

  final String name;
  final String key;
  final String site; // 'YouTube', ...
  final String type; // 'Trailer', 'Teaser', ...

  bool get isYoutube => site == 'YouTube';
  String get youtubeUrl => 'https://www.youtube.com/watch?v=$key';

  factory Video.fromJson(Map<String, dynamic> json) => Video(
        name: (json['name'] as String?) ?? '',
        key: (json['key'] as String?) ?? '',
        site: (json['site'] as String?) ?? '',
        type: (json['type'] as String?) ?? '',
      );
}

/// Fiche détaillée d'un film/série (avec casting et vidéos via `append_to_response`).
class MediaDetails {
  const MediaDetails({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.runtime,
    required this.genres,
    required this.directors,
    required this.cast,
    required this.videos,
  });

  final int tmdbId;
  final String mediaType;
  final String title;
  final String originalTitle;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final int? runtime; // minutes (films)
  final List<Genre> genres;
  final List<String> directors; // réalisateur(s) / créateur(s)
  final List<CastMember> cast;
  final List<Video> videos;

  int? get releaseYear {
    if (releaseDate == null || releaseDate!.length < 4) return null;
    return int.tryParse(releaseDate!.substring(0, 4));
  }

  List<int> get genreIds => genres.map((g) => g.id).toList();

  List<Video> get trailers =>
      videos.where((v) => v.isYoutube && v.type == 'Trailer').toList();

  factory MediaDetails.fromJson(Map<String, dynamic> json, String mediaType) {
    final isMovie = mediaType == 'movie';
    final credits = json['credits'] as Map<String, dynamic>?;
    final videosBlock = json['videos'] as Map<String, dynamic>?;

    // Réalisateur(s) : pour un film, l'équipe (crew) dont le poste est « Director » ;
    // pour une série, les créateurs (created_by).
    final crew = (credits?['crew'] as List<dynamic>? ?? []);
    var directors = crew
        .whereType<Map<String, dynamic>>()
        .where((c) => c['job'] == 'Director')
        .map((c) => (c['name'] as String?) ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (directors.isEmpty && !isMovie) {
      directors = (json['created_by'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((c) => (c['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    }

    return MediaDetails(
      tmdbId: json['id'] as int,
      mediaType: mediaType,
      title: (isMovie ? json['title'] : json['name']) as String? ?? 'Sans titre',
      originalTitle:
          (isMovie ? json['original_title'] : json['original_name']) as String? ??
              '',
      overview: (json['overview'] as String?) ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate:
          (isMovie ? json['release_date'] : json['first_air_date']) as String?,
      voteAverage: ((json['vote_average'] as num?) ?? 0).toDouble(),
      runtime: isMovie
          ? json['runtime'] as int?
          : ((json['episode_run_time'] as List<dynamic>?)?.isNotEmpty ?? false
              ? (json['episode_run_time'] as List<dynamic>).first as int?
              : null),
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((e) => Genre.fromJson(e as Map<String, dynamic>))
          .toList(),
      directors: directors,
      cast: ((credits?['cast'] as List<dynamic>?) ?? [])
          .take(15)
          .map((e) => CastMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      videos: ((videosBlock?['results'] as List<dynamic>?) ?? [])
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
