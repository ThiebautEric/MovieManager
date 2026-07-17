import 'film.dart';
import 'film_season.dart';

/// Un visionnage (ligne de la table `history`). LA donnée précieuse : jamais
/// d'effacement automatique. `seasonNumber` null = œuvre entière ;
/// `episodeNumber` non nul = visionnage d'un épisode précis de la saison
/// (nom et durée dénormalisés depuis TMDB à l'ajout). Note et commentaire
/// propres à cette séance. Indépendante de la collection.
class HistoryEntry {
  HistoryEntry({
    this.id,
    required this.filmId,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
    this.episodeRuntime,
    required this.watchedAt,
    this.rating,
    this.comment,
  });

  final String? id;
  final String filmId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final int? episodeRuntime; // minutes
  final DateTime watchedAt;
  final double? rating;
  final String? comment;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String?,
        filmId: json['film_id'] as String,
        seasonNumber: (json['season_number'] as num?)?.toInt(),
        episodeNumber: (json['episode_number'] as num?)?.toInt(),
        episodeName: json['episode_name'] as String?,
        episodeRuntime: (json['episode_runtime'] as num?)?.toInt(),
        watchedAt: DateTime.parse(json['watched_at'] as String),
        rating: (json['rating'] as num?)?.toDouble(),
        comment: json['comment'] as String?,
      );

  Map<String, dynamic> toUpsertJson() => {
        'film_id': filmId,
        'season_number': seasonNumber,
        // N'envoie les colonnes épisode que si renseignées : les ajouts
        // « saison » restent compatibles avec une base non migrée.
        if (episodeNumber != null) 'episode_number': episodeNumber,
        if (episodeName != null) 'episode_name': episodeName,
        if (episodeRuntime != null) 'episode_runtime': episodeRuntime,
        'watched_at': watchedAt.toUtc().toIso8601String(),
        'rating': rating,
        'comment': comment,
      };

  Map<String, dynamic> toFullJson() => {...toUpsertJson(), 'id': id};
}

/// Vue composite (jointure faite par le repository) : un visionnage enrichi de
/// son film et, le cas échéant, de sa saison.
class HistoryView {
  HistoryView({
    required this.entry,
    required this.film,
    this.season,
  });

  final HistoryEntry entry;
  final Film film;
  final FilmSeason? season;

  String? get id => entry.id;
  int? get seasonNumber => entry.seasonNumber;
  int? get episodeNumber => entry.episodeNumber;
  String? get episodeName => entry.episodeName;
  DateTime get watchedAt => entry.watchedAt;
  double? get rating => entry.rating;
  String? get comment => entry.comment;

  String? get posterPath => season?.posterPath ?? film.posterPath;

  /// Durée totale en minutes : le film, l'épisode (durée exacte si connue),
  /// ou le cumul de la saison — somme exacte des épisodes si connue, sinon
  /// estimation épisodes × durée.
  int? get totalMinutes {
    if (film.isMovie) return film.runtime;
    if (entry.episodeNumber != null) {
      return entry.episodeRuntime ?? film.runtime;
    }
    final exact = season?.runtimeMinutes;
    if (exact != null) return exact;
    final eps = season?.episodeCount;
    final rt = film.runtime;
    if (eps == null || rt == null) return null;
    return eps * rt;
  }

  /// Vrai si [totalMinutes] est une somme exacte (pas une estimation « ≈ »).
  bool get isExactDuration {
    if (film.isMovie) return true;
    if (entry.episodeNumber != null) return entry.episodeRuntime != null;
    return season?.runtimeMinutes != null;
  }
}
