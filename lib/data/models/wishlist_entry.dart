import 'film.dart';
import 'film_season.dart';

/// Une entrée du pense-bête (table `wishlist`) : un titre (ou une saison) à
/// voir ou à acheter plus tard. `seasonNumber` null = œuvre entière.
/// Convertible côté app en possession (collection) ou visionnage (history).
class WishlistEntry {
  WishlistEntry({
    this.id,
    required this.filmId,
    this.seasonNumber,
    this.addedAt,
  });

  final String? id;
  final String filmId;
  final int? seasonNumber;
  final DateTime? addedAt;

  factory WishlistEntry.fromJson(Map<String, dynamic> json) => WishlistEntry(
        id: json['id'] as String?,
        filmId: json['film_id'] as String,
        seasonNumber: (json['season_number'] as num?)?.toInt(),
        addedAt: json['added_at'] != null
            ? DateTime.tryParse(json['added_at'] as String)
            : null,
      );

  Map<String, dynamic> toUpsertJson() => {
        'film_id': filmId,
        'season_number': seasonNumber,
        if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
      };

  Map<String, dynamic> toFullJson() => {...toUpsertJson(), 'id': id};
}

/// Vue composite pour l'affichage : l'entrée enrichie de son film et, le cas
/// échéant, de sa saison.
class WishlistView {
  WishlistView({
    required this.entry,
    required this.film,
    this.season,
  });

  final WishlistEntry entry;
  final Film film;
  final FilmSeason? season;

  String? get id => entry.id;
  int? get seasonNumber => entry.seasonNumber;
  DateTime? get addedAt => entry.addedAt;

  /// Affiche : celle de la saison si disponible, sinon celle du film.
  String? get posterPath => season?.posterPath ?? film.posterPath;
}
