import '../../tmdb/models/media_details.dart';

/// Catalogue d'une saison (séries) réellement suivie en collection ou historique.
/// Métadonnées TMDB en lecture seule (affiche/nom), liées à un [Film].
class FilmSeason {
  FilmSeason({
    this.id,
    this.filmId,
    required this.seasonNumber,
    this.name,
    this.posterPath,
    this.airYear,
    this.episodeCount,
  });

  final String? id;
  final String? filmId; // null tant que le film n'est pas inséré
  final int seasonNumber;
  final String? name;
  final String? posterPath;
  final int? airYear;
  final int? episodeCount; // pour la durée cumulée (× durée d'épisode)

  factory FilmSeason.fromJson(Map<String, dynamic> json) => FilmSeason(
        id: json['id'] as String?,
        filmId: json['film_id'] as String?,
        seasonNumber: (json['season_number'] as num).toInt(),
        name: json['name'] as String?,
        posterPath: json['poster_path'] as String?,
        airYear: (json['air_year'] as num?)?.toInt(),
        episodeCount: (json['episode_count'] as num?)?.toInt(),
      );

  Map<String, dynamic> toUpsertJson() => {
        'season_number': seasonNumber,
        'name': name,
        'poster_path': posterPath,
        'air_year': airYear,
        'episode_count': episodeCount,
      };

  Map<String, dynamic> toFullJson() =>
      {...toUpsertJson(), 'id': id, 'film_id': filmId};

  factory FilmSeason.fromInfo(SeasonInfo s) => FilmSeason(
        seasonNumber: s.seasonNumber,
        name: s.name.isEmpty ? null : s.name,
        posterPath: s.posterPath,
        airYear: s.year,
        episodeCount: s.episodeCount > 0 ? s.episodeCount : null,
      );
}
