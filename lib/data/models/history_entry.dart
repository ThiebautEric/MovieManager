import 'film.dart';
import 'film_season.dart';

/// Un visionnage (ligne de la table `history`). LA donnée précieuse : jamais
/// d'effacement automatique. `seasonNumber` null = œuvre entière. Note et
/// commentaire propres à cette séance. Indépendante de la collection.
class HistoryEntry {
  HistoryEntry({
    this.id,
    required this.filmId,
    this.seasonNumber,
    required this.watchedAt,
    this.rating,
    this.comment,
  });

  final String? id;
  final String filmId;
  final int? seasonNumber;
  final DateTime watchedAt;
  final double? rating;
  final String? comment;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String?,
        filmId: json['film_id'] as String,
        seasonNumber: (json['season_number'] as num?)?.toInt(),
        watchedAt: DateTime.parse(json['watched_at'] as String),
        rating: (json['rating'] as num?)?.toDouble(),
        comment: json['comment'] as String?,
      );

  Map<String, dynamic> toUpsertJson() => {
        'film_id': filmId,
        'season_number': seasonNumber,
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
  DateTime get watchedAt => entry.watchedAt;
  double? get rating => entry.rating;
  String? get comment => entry.comment;

  String? get posterPath => season?.posterPath ?? film.posterPath;
}
