import 'film.dart';
import 'film_season.dart';

/// Une possession (ligne de la table `collection`). `seasonNumber` null = œuvre
/// entière. Indépendante de l'historique.
class CollectionEntry {
  CollectionEntry({
    this.id,
    required this.filmId,
    this.seasonNumber,
    required this.medium,
    this.addedAt,
  });

  final String? id;
  final String filmId;
  final int? seasonNumber;
  final Medium medium;
  final DateTime? addedAt;

  factory CollectionEntry.fromJson(Map<String, dynamic> json) => CollectionEntry(
        id: json['id'] as String?,
        filmId: json['film_id'] as String,
        seasonNumber: (json['season_number'] as num?)?.toInt(),
        medium: Medium.fromName(json['medium'] as String?),
        addedAt: json['added_at'] != null
            ? DateTime.tryParse(json['added_at'] as String)
            : null,
      );

  Map<String, dynamic> toUpsertJson() => {
        'film_id': filmId,
        'season_number': seasonNumber,
        'medium': medium.name,
        if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
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
  DateTime? get addedAt => entry.addedAt;

  /// Affiche : celle de la saison si disponible, sinon celle du film.
  String? get posterPath => season?.posterPath ?? film.posterPath;
}
