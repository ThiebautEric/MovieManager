import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../tmdb/models/search_hit.dart';
import '../../tmdb/tmdb_providers.dart';

/// Requête de recherche courante.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Résultats de recherche TMDB (films, séries et personnalités) pour la requête
/// courante.
final searchResultsProvider = FutureProvider<List<SearchHit>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return [];
  return ref.watch(tmdbClientProvider).searchMulti(query);
});
