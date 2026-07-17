/// Un épisode d'une saison (métadonnées TMDB, lecture seule) — utilisé pour la
/// notation par épisode.
class EpisodeInfo {
  const EpisodeInfo({
    required this.episodeNumber,
    required this.name,
    required this.runtime,
    required this.airDate,
    required this.stillPath,
  });

  final int episodeNumber;
  final String name;
  final int? runtime; // minutes
  final String? airDate; // 'YYYY-MM-DD'
  final String? stillPath; // image 16:9 de l'épisode (TMDB)

  int? get airYear {
    if (airDate == null || airDate!.length < 4) return null;
    return int.tryParse(airDate!.substring(0, 4));
  }

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) => EpisodeInfo(
        episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        runtime: (json['runtime'] as num?)?.toInt(),
        airDate: json['air_date'] as String?,
        stillPath: json['still_path'] as String?,
      );

  /// Parse la réponse de `/tv/{id}/season/{n}`.
  static List<EpisodeInfo> listFromSeasonJson(Map<String, dynamic> json) =>
      (json['episodes'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(EpisodeInfo.fromJson)
          .toList();
}
