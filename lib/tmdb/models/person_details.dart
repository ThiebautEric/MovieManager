/// Catégorie d'une entrée de filmographie (pour le regroupement).
enum FilmoCategory { film, serie, reportage, autre }

/// Un rôle dans la filmographie d'une personne.
class FilmographyItem {
  const FilmographyItem({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.releaseYear,
    required this.character,
    required this.genreIds,
  });

  final int tmdbId;
  final String mediaType; // 'movie' | 'tv'
  final String title;
  final String? posterPath;
  final int? releaseYear;
  final String character;
  final List<int> genreIds;

  // Identifiants de genres TMDB utiles au classement.
  static const _documentary = 99;
  static const _news = 10763;
  static const _talk = 10767;
  static const _reality = 10764;

  /// Classe l'entrée : reportage (doc/news), puis film, série, ou autre
  /// (talk-show, télé-réalité…).
  FilmoCategory get category {
    if (genreIds.contains(_documentary) || genreIds.contains(_news)) {
      return FilmoCategory.reportage;
    }
    if (genreIds.contains(_talk) || genreIds.contains(_reality)) {
      return FilmoCategory.autre;
    }
    if (mediaType == 'movie') return FilmoCategory.film;
    if (mediaType == 'tv') return FilmoCategory.serie;
    return FilmoCategory.autre;
  }

  static int? _yearOf(String? date) {
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  static FilmographyItem? fromJson(Map<String, dynamic> json, String mediaType) {
    final id = json['id'] as int?;
    if (id == null) return null;
    final isMovie = mediaType == 'movie';
    return FilmographyItem(
      tmdbId: id,
      mediaType: mediaType,
      title: (isMovie ? json['title'] : json['name']) as String? ?? 'Sans titre',
      posterPath: json['poster_path'] as String?,
      releaseYear: _yearOf(
          (isMovie ? json['release_date'] : json['first_air_date']) as String?),
      character: (json['character'] as String?) ?? '',
      genreIds: (json['genre_ids'] as List<dynamic>? ?? [])
          .whereType<int>()
          .toList(),
    );
  }
}

/// Fiche détaillée d'une personne (acteur/réalisateur) avec sa filmographie.
class PersonDetails {
  const PersonDetails({
    required this.id,
    required this.name,
    required this.biography,
    required this.birthday,
    required this.deathday,
    required this.placeOfBirth,
    required this.profilePath,
    required this.knownForDepartment,
    required this.filmography,
  });

  final int id;
  final String name;
  final String biography;
  final String? birthday; // 'YYYY-MM-DD'
  final String? deathday;
  final String? placeOfBirth;
  final String? profilePath;
  final String knownForDepartment;
  final List<FilmographyItem> filmography;

  /// Âge calculé à partir de la date de naissance (et de décès le cas échéant).
  int? ageAt(DateTime now) {
    final b = _parse(birthday);
    if (b == null) return null;
    final end = _parse(deathday) ?? now;
    var age = end.year - b.year;
    if (end.month < b.month || (end.month == b.month && end.day < b.day)) {
      age--;
    }
    return age;
  }

  static DateTime? _parse(String? d) =>
      (d == null || d.isEmpty) ? null : DateTime.tryParse(d);

  factory PersonDetails.fromJson(Map<String, dynamic> json) {
    final movieCast =
        ((json['movie_credits'] as Map<String, dynamic>?)?['cast']
                as List<dynamic>? ??
            []);
    final tvCast = ((json['tv_credits'] as Map<String, dynamic>?)?['cast']
            as List<dynamic>? ??
        []);

    final items = <String, FilmographyItem>{};
    for (final e in movieCast) {
      final item = FilmographyItem.fromJson(e as Map<String, dynamic>, 'movie');
      if (item != null) items['movie_${item.tmdbId}'] = item;
    }
    for (final e in tvCast) {
      final item = FilmographyItem.fromJson(e as Map<String, dynamic>, 'tv');
      if (item != null) items['tv_${item.tmdbId}'] = item;
    }
    final filmography = items.values.toList()
      ..sort((a, b) => (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));

    return PersonDetails(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      biography: (json['biography'] as String?) ?? '',
      birthday: json['birthday'] as String?,
      deathday: json['deathday'] as String?,
      placeOfBirth: json['place_of_birth'] as String?,
      profilePath: json['profile_path'] as String?,
      knownForDepartment: (json['known_for_department'] as String?) ?? '',
      filmography: filmography,
    );
  }
}
