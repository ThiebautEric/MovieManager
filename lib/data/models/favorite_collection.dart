/// Une collection TMDB (saga de films) marquée comme favorite.
class FavoriteCollection {
  const FavoriteCollection({
    required this.collectionId,
    required this.name,
    this.posterPath,
    this.addedAt,
  });

  final int collectionId;
  final String name;
  final String? posterPath;
  final DateTime? addedAt;

  Map<String, dynamic> toJson() => {
        'collection_id': collectionId,
        'name': name,
        'poster_path': posterPath,
        'added_at': (addedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .toIso8601String(),
      };

  factory FavoriteCollection.fromJson(Map<String, dynamic> json) =>
      FavoriteCollection(
        collectionId: (json['collection_id'] as num).toInt(),
        name: (json['name'] as String?) ?? '',
        posterPath: json['poster_path'] as String?,
        addedAt: json['added_at'] != null
            ? DateTime.tryParse(json['added_at'] as String)
            : null,
      );
}
