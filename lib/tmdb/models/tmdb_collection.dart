import 'media_summary.dart';

/// Référence légère à une collection TMDB (saga), depuis `belongs_to_collection`
/// d'un film ou une entrée favorite.
class CollectionRef {
  const CollectionRef({required this.id, required this.name, this.posterPath});

  final int id;
  final String name;
  final String? posterPath;

  static CollectionRef? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = (json['id'] as num?)?.toInt();
    if (id == null) return null;
    return CollectionRef(
      id: id,
      name: (json['name'] as String?) ?? '',
      posterPath: json['poster_path'] as String?,
    );
  }
}

/// Collection TMDB complète (saga de films) : endpoint `/collection/{id}`.
/// `parts` = tous les films de la saga, triés par date de sortie.
class TmdbCollection {
  const TmdbCollection({
    required this.id,
    required this.name,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.parts,
  });

  final int id;
  final String name;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final List<MediaSummary> parts;

  factory TmdbCollection.fromJson(Map<String, dynamic> json) {
    final parts = (json['parts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => MediaSummary.fromJsonAs(e, 'movie'))
        .whereType<MediaSummary>()
        .toList();
    // Ordre chronologique (dates absentes/vides en dernier).
    parts.sort((a, b) {
      final ad = a.releaseDate, bd = b.releaseDate;
      final aEmpty = ad == null || ad.isEmpty;
      final bEmpty = bd == null || bd.isEmpty;
      if (aEmpty && bEmpty) return 0;
      if (aEmpty) return 1;
      if (bEmpty) return -1;
      return ad.compareTo(bd);
    });
    return TmdbCollection(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      parts: parts,
    );
  }
}
