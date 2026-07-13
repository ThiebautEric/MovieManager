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

/// Membre de l'équipe (réalisateur / créateur), cliquable vers sa fiche.
class CrewMember {
  const CrewMember({
    required this.id,
    required this.name,
    required this.profilePath,
  });

  final int id; // identifiant TMDB de la personne
  final String name;
  final String? profilePath;

  factory CrewMember.fromJson(Map<String, dynamic> json) => CrewMember(
        id: (json['id'] as int?) ?? 0,
        name: (json['name'] as String?) ?? '',
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

/// Une saison d'une série (métadonnées TMDB, lecture seule).
class SeasonInfo {
  const SeasonInfo({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    required this.posterPath,
    required this.airDate,
    required this.overview,
  });

  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String? posterPath;
  final String? airDate;
  final String overview;

  int? get year {
    if (airDate == null || airDate!.length < 4) return null;
    return int.tryParse(airDate!.substring(0, 4));
  }

  factory SeasonInfo.fromJson(Map<String, dynamic> json) => SeasonInfo(
        seasonNumber: (json['season_number'] as int?) ?? 0,
        name: (json['name'] as String?) ?? '',
        episodeCount: (json['episode_count'] as int?) ?? 0,
        posterPath: json['poster_path'] as String?,
        airDate: json['air_date'] as String?,
        overview: (json['overview'] as String?) ?? '',
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
    this.originCountry,
    this.seasons = const [],
    this.numberOfEpisodes,
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
  final int? runtime; // minutes (film entier, ou UN épisode pour une série)

  /// Nombre total d'épisodes (séries uniquement).
  final int? numberOfEpisodes;
  final List<Genre> genres;
  final List<CrewMember> directors; // réalisateur(s) / créateur(s), cliquables
  final List<CastMember> cast;
  final List<Video> videos;

  /// Pays d'origine principal (code ISO-3166-1, ex. « US », « FR »), ou null.
  final String? originCountry;

  /// Saisons (séries uniquement ; vide pour les films), triées par numéro,
  /// les « Spéciaux » (saison 0) en dernier.
  final List<SeasonInfo> seasons;

  int? get releaseYear {
    if (releaseDate == null || releaseDate!.length < 4) return null;
    return int.tryParse(releaseDate!.substring(0, 4));
  }

  List<int> get genreIds => genres.map((g) => g.id).toList();

  List<Video> get trailers =>
      videos.where((v) => v.isYoutube && v.type == 'Trailer').toList();

  /// Durée totale de l'œuvre en minutes : le film, ou le CUMUL de tous les
  /// épisodes (approximation : nb d'épisodes × durée d'épisode, TMDB ne
  /// fournissant pas de total).
  int? get totalRuntime {
    if (mediaType == 'movie') return runtime;
    if (runtime == null || numberOfEpisodes == null) return null;
    return runtime! * numberOfEpisodes!;
  }

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
        .map((c) => CrewMember.fromJson(c))
        .where((c) => c.name.isNotEmpty)
        .toList();
    if (directors.isEmpty && !isMovie) {
      directors = (json['created_by'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((c) => CrewMember.fromJson(c))
          .where((c) => c.name.isNotEmpty)
          .toList();
    }
    // Dédoublonne (un réalisateur peut apparaître sous plusieurs postes).
    final seenCrew = <int>{};
    directors = directors.where((c) => seenCrew.add(c.id)).toList();

    // Pays d'origine : `origin_country` (séries surtout), sinon le 1er pays de
    // production.
    final originList =
        (json['origin_country'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];
    final prodCountries = (json['production_countries'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const [];
    final originCountry = originList.isNotEmpty
        ? originList.first
        : (prodCountries.isNotEmpty
            ? prodCountries.first['iso_3166_1'] as String?
            : null);

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
      // PAS de repli sur last_episode_to_air.runtime : les finals de série
      // sont souvent anormalement longs et faussent tous les cumuls.
      runtime: isMovie
          ? json['runtime'] as int?
          : ((json['episode_run_time'] as List<dynamic>?)?.isNotEmpty ?? false
              ? (json['episode_run_time'] as List<dynamic>).first as int?
              : null),
      numberOfEpisodes: isMovie ? null : json['number_of_episodes'] as int?,
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((e) => Genre.fromJson(e as Map<String, dynamic>))
          .toList(),
      directors: directors,
      cast: ((credits?['cast'] as List<dynamic>?) ?? [])
          .map((e) => CastMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      videos: ((videosBlock?['results'] as List<dynamic>?) ?? [])
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList(),
      originCountry: originCountry,
      seasons: isMovie
          ? const []
          : (((json['seasons'] as List<dynamic>?) ?? [])
              .map((e) => SeasonInfo.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) {
              // Spéciaux (saison 0) toujours en dernier.
              if (a.seasonNumber == 0) return 1;
              if (b.seasonNumber == 0) return -1;
              return a.seasonNumber.compareTo(b.seasonNumber);
            })),
    );
  }
}
