/// Une personne (acteur/réalisateur) marquée comme favorite.
class FavoritePerson {
  const FavoritePerson({
    required this.personId,
    required this.name,
    this.profilePath,
    this.addedAt,
  });

  final int personId;
  final String name;
  final String? profilePath;
  final DateTime? addedAt;

  Map<String, dynamic> toJson() => {
        'person_id': personId,
        'name': name,
        'profile_path': profilePath,
        'added_at': (addedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .toIso8601String(),
      };

  factory FavoritePerson.fromJson(Map<String, dynamic> json) => FavoritePerson(
        personId: (json['person_id'] as num).toInt(),
        name: (json['name'] as String?) ?? '',
        profilePath: json['profile_path'] as String?,
        addedAt: json['added_at'] != null
            ? DateTime.tryParse(json['added_at'] as String)
            : null,
      );
}
