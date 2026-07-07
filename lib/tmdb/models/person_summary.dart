/// Résultat de recherche TMDB : une personnalité (acteur, réalisateur…).
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.name,
    required this.profilePath,
    required this.knownForDepartment,
  });

  final int id;
  final String name;
  final String? profilePath;
  final String knownForDepartment; // 'Acting', 'Directing', ...

  factory PersonSummary.fromJson(Map<String, dynamic> json) => PersonSummary(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
        profilePath: json['profile_path'] as String?,
        knownForDepartment: (json['known_for_department'] as String?) ?? '',
      );
}
