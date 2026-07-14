import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import 'models/genre.dart';
import 'models/media_details.dart';
import 'models/media_summary.dart';
import 'models/person_details.dart';
import 'models/person_summary.dart';
import 'models/search_hit.dart';

/// Client de l'API TMDB (endpoints v3).
///
/// Gère les deux formes d'authentification TMDB :
/// - **clé API v3** (32 caractères hex) → passée en paramètre `api_key`.
/// - **token v4** (JWT « Bearer », contient des points) → en-tête `Authorization`.
class TmdbClient {
  TmdbClient({Dio? dio, this.language = 'fr-FR'})
      : _dio = dio ?? _buildDio(AppConfig.tmdbToken);

  /// Le token v4 est un JWT (contient des points) ; la clé v3 ne l'est pas.
  static bool _isV4Token(String token) => token.contains('.');

  static Dio _buildDio(String token) {
    final isV4 = _isV4Token(token);
    return Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      headers: {
        'Accept': 'application/json',
        if (isV4) 'Authorization': 'Bearer $token',
      },
      // Pour une clé v3, TMDB attend `api_key` sur chaque requête.
      queryParameters: isV4 ? null : {'api_key': token},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  final Dio _dio;
  final String language;

  static const String imageBase = 'https://image.tmdb.org/t/p';

  /// Construit une URL d'image TMDB. [size] : w185, w342, w500, original, ...
  static String? imageUrl(String? path, {String size = 'w342'}) {
    if (path == null || path.isEmpty) return null;
    return '$imageBase/$size$path';
  }

  /// Recherche multi (films + séries + personnalités), dans l'ordre de
  /// pertinence renvoyé par TMDB.
  Future<List<SearchHit>> searchMulti(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final res = await _dio.get('/search/multi', queryParameters: {
      'query': query,
      'language': language,
      'page': page,
      'include_adult': false,
    });
    final results = (res.data['results'] as List<dynamic>? ?? []);
    final hits = <SearchHit>[];
    for (final e in results.whereType<Map<String, dynamic>>()) {
      switch (e['media_type'] as String?) {
        case 'movie':
        case 'tv':
          final m = MediaSummary.fromJson(e);
          if (m != null) hits.add(MediaHit(m));
        case 'person':
          hits.add(PersonHit(PersonSummary.fromJson(e)));
      }
    }
    return hits;
  }

  /// Titre seul d'un média (requête légère, utilisée pour le mode
  /// « titres anglais » avec un client en-US).
  Future<String?> title(int tmdbId, String mediaType) async {
    final res = await _dio.get('/$mediaType/$tmdbId', queryParameters: {
      'language': language,
    });
    final data = res.data as Map<String, dynamic>;
    return (mediaType == 'movie' ? data['title'] : data['name']) as String?;
  }

  /// Fiche détaillée d'un média, avec casting et vidéos (append_to_response).
  Future<MediaDetails> details(int tmdbId, String mediaType) async {
    final res = await _dio.get('/$mediaType/$tmdbId', queryParameters: {
      'language': language,
      'append_to_response': 'credits,videos',
    });
    return MediaDetails.fromJson(res.data as Map<String, dynamic>, mediaType);
  }

  /// Fiche détaillée d'une personne, avec sa filmographie (movie + tv credits).
  Future<PersonDetails> person(int personId) async {
    final res = await _dio.get('/person/$personId', queryParameters: {
      'language': language,
      'append_to_response': 'movie_credits,tv_credits',
    });
    return PersonDetails.fromJson(res.data as Map<String, dynamic>);
  }

  /// Liste des genres (films + séries), fusionnée par id.
  Future<List<Genre>> genres() async {
    final responses = await Future.wait([
      _dio.get('/genre/movie/list', queryParameters: {'language': language}),
      _dio.get('/genre/tv/list', queryParameters: {'language': language}),
    ]);
    final byId = <int, Genre>{};
    for (final res in responses) {
      for (final g in (res.data['genres'] as List<dynamic>? ?? [])) {
        final genre = Genre.fromJson(g as Map<String, dynamic>);
        byId[genre.id] = genre;
      }
    }
    final list = byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}
