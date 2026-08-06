import 'film.dart';
import 'film_season.dart';

/// Une possession (ligne de la table `collection`). `seasonNumber` null = œuvre
/// entière. `episodeNumber` non null = épisode individuel.
class CollectionEntry {
  CollectionEntry({
    this.id,
    required this.filmId,
    this.seasonNumber,
    this.episodeNumber,
    this.historyId,
    required this.medium,
    this.addedAt,
    this.seasonAirYear,
    this.episodeAirYear,
  });

  final String? id;
  final String filmId;
  final int? seasonNumber;
  final int? episodeNumber;
  /// UUID de l'entrée historique liée (saisie rapide depuis le Verlauf).
  /// Null pour les entrées ajoutées depuis la fiche détail.
  final String? historyId;
  final Medium medium;
  final DateTime? addedAt;
  /// Année de diffusion TMDB de la saison (pour tri/groupement, sans appel TMDB).
  final int? seasonAirYear;
  /// Année de diffusion TMDB de l'épisode (priorité sur [seasonAirYear]).
  final int? episodeAirYear;

  factory CollectionEntry.fromJson(Map<String, dynamic> json) => CollectionEntry(
        id: json['id'] as String?,
        filmId: json['film_id'] as String,
        seasonNumber: (json['season_number'] as num?)?.toInt(),
        episodeNumber: (json['episode_number'] as num?)?.toInt(),
        historyId: json['history_id'] as String?,
        medium: Medium.fromName(json['medium'] as String?),
        addedAt: json['added_at'] != null
            ? DateTime.tryParse(json['added_at'] as String)
            : null,
        seasonAirYear: (json['season_air_year'] as num?)?.toInt(),
        episodeAirYear: (json['episode_air_year'] as num?)?.toInt(),
      );

  Map<String, dynamic> toUpsertJson() => {
        'film_id': filmId,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        if (historyId != null) 'history_id': historyId,
        'medium': medium.name,
        if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
        if (seasonAirYear != null) 'season_air_year': seasonAirYear,
        if (episodeAirYear != null) 'episode_air_year': episodeAirYear,
      };

  Map<String, dynamic> toFullJson() => {...toUpsertJson(), 'id': id};
}

/// Vue composite (jointure faite par le repository) pour l'affichage : une
/// possession enrichie de son film et, le cas échéant, de sa saison.
class CollectionView {
  CollectionView({
    required this.entry,
    required this.film,
    this.season,
  });

  final CollectionEntry entry;
  final Film film;
  final FilmSeason? season;

  String? get id => entry.id;
  Medium get medium => entry.medium;
  int? get seasonNumber => entry.seasonNumber;
  int? get episodeNumber => entry.episodeNumber;
  String? get historyId => entry.historyId;
  DateTime? get addedAt => entry.addedAt;
  int? get seasonAirYear => entry.seasonAirYear;
  int? get episodeAirYear => entry.episodeAirYear;

  /// Affiche : celle de la saison si disponible, sinon celle du film.
  String? get posterPath => season?.posterPath ?? film.posterPath;

  /// Durée totale en minutes : le film, ou le cumul de la saison — somme
  /// exacte des épisodes si connue, sinon estimation épisodes × durée.
  int? get totalMinutes {
    if (film.isMovie) return film.runtime;
    final exact = season?.runtimeMinutes;
    if (exact != null) return exact;
    final eps = season?.episodeCount;
    final rt = film.runtime;
    if (eps == null || rt == null) return null;
    return eps * rt;
  }

  /// Vrai si [totalMinutes] est une somme exacte (pas une estimation « ≈ »).
  bool get isExactDuration => film.isMovie || season?.runtimeMinutes != null;
}
