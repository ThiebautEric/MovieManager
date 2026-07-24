import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../tmdb/models/search_hit.dart';
import '../../tmdb/tmdb_providers.dart';

/// Requête de recherche courante.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Résultats de recherche TMDB (films, séries et personnalités) pour la requête
/// courante. Annule la requête HTTP en cours dès que la requête change.
final searchResultsProvider =
    FutureProvider.autoDispose<List<SearchHit>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return [];
  final token = CancelToken();
  ref.onDispose(token.cancel);
  try {
    return await ref
        .watch(tmdbClientProvider)
        .searchMulti(query, cancelToken: token);
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) return [];
    rethrow;
  }
});
