import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../tmdb/models/media_summary.dart';
import '../../tmdb/tmdb_providers.dart';

/// Requête de recherche courante.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Résultats de recherche TMDB pour la requête courante.
final searchResultsProvider = FutureProvider<List<MediaSummary>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return [];
  return ref.watch(tmdbClientProvider).searchMulti(query);
});
