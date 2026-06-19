/// Genre TMDB (id + nom).
class Genre {
  const Genre({required this.id, required this.name});

  final int id;
  final String name;

  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? '',
      );
}
