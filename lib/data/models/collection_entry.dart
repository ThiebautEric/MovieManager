import 'film.dart';
import 'film_season.dart';
import 'history_entry.dart';

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
      );

  Map<String, dynamic> toUpsertJson() => {
        'film_id': filmId,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        if (historyId != null) 'history_id': historyId,
        'medium': medium.name,
        if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
      };

  Map<String, dynamic> toFullJson() => {...toUpsertJson(), 'id': id};
}

/// Vue composite (jointure faite par le repository) pour l'affichage : une
/// possession enrichie de son film, de sa saison et de l'entrée historique liée.
class CollectionView {
  CollectionView({
    required this.entry,
    required this.film,
    this.season,
    this.linkedHistory,
  });

  final CollectionEntry entry;
  final Film film;
  final FilmSeason? season;
  /// Visionnage lié (non null quand history_id est renseigné).
  /// Donne accès à episode_runtime sans dupliquer la donnée dans collection.
  final HistoryEntry? linkedHistory;

  String? get id => entry.id;
  Medium get medium => entry.medium;
  int? get seasonNumber => entry.seasonNumber;
  int? get episodeNumber => entry.episodeNumber;
  String? get historyId => entry.historyId;
  DateTime? get addedAt => entry.addedAt;

  /// Affiche : celle de la saison si disponible, sinon celle du film.
  String? get posterPath => season?.posterPath ?? film.posterPath;

  /// Durée en minutes : exacte uniquement (jamais estimée).
  /// - Film : runtime TMDB stocké.
  /// - Saison entière : somme exacte des épisodes (backfill film_seasons).
  /// - Épisode individuel : runtime du visionnage lié (linkedHistory),
  ///   ou null si pas de visionnage lié (TMDB fallback dans l'écran).
  int? get totalMinutes {
    if (film.isMovie) return film.runtime;
    if (episodeNumber != null) return linkedHistory?.episodeRuntime;
    return season?.runtimeMinutes;
  }

  bool get isExactDuration => true;
}
