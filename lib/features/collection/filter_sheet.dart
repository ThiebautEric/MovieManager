import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/collection_repository.dart';
import '../../tmdb/tmdb_providers.dart';
import 'collection_filter.dart';

/// Feuille modale de configuration des filtres de la collection.
class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(collectionFilterProvider);
    final notifier = ref.read(collectionFilterProvider.notifier);
    final genresById = ref.watch(genresByIdProvider);
    final items = ref.watch(collectionStreamProvider).value ?? [];

    // Genres et années réellement présents dans la collection.
    final presentGenres = <int>{for (final i in items) ...i.genres}.toList()
      ..sort((a, b) =>
          (genresById[a] ?? '').compareTo(genresById[b] ?? ''));
    final presentYears = <int>{
      for (final i in items)
        if (i.releaseYear != null) i.releaseYear!
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: filter.mediaType == null,
                  onSelected: (_) =>
                      notifier.state = filter.copyWith(clearMediaType: true),
                ),
                ChoiceChip(
                  label: const Text('Films'),
                  selected: filter.mediaType == 'movie',
                  onSelected: (_) =>
                      notifier.state = filter.copyWith(mediaType: 'movie'),
                ),
                ChoiceChip(
                  label: const Text('Séries'),
                  selected: filter.mediaType == 'tv',
                  onSelected: (_) =>
                      notifier.state = filter.copyWith(mediaType: 'tv'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: filter.genreId,
              decoration: const InputDecoration(labelText: 'Genre'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous')),
                ...presentGenres.map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(genresById[g] ?? 'Genre $g'),
                    )),
              ],
              onChanged: (v) => notifier.state = v == null
                  ? filter.copyWith(clearGenre: true)
                  : filter.copyWith(genreId: v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: filter.year,
              decoration: const InputDecoration(labelText: 'Année'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Toutes')),
                ...presentYears.map((y) =>
                    DropdownMenuItem(value: y, child: Text('$y'))),
              ],
              onChanged: (v) => notifier.state = v == null
                  ? filter.copyWith(clearYear: true)
                  : filter.copyWith(year: v),
            ),
            const SizedBox(height: 16),
            Text('Note minimale : '
                '${filter.minRating == 0 ? 'aucune' : filter.minRating.toStringAsFixed(1)}'),
            Slider(
              value: filter.minRating,
              min: 0,
              max: 10,
              divisions: 20,
              label: filter.minRating.toStringAsFixed(1),
              onChanged: (v) =>
                  notifier.state = filter.copyWith(minRating: v),
            ),
            const SizedBox(height: 8),
            const Text('Statut'),
            const SizedBox(height: 8),
            SegmentedButton<WatchedFilter>(
              segments: const [
                ButtonSegment(value: WatchedFilter.all, label: Text('Tous')),
                ButtonSegment(value: WatchedFilter.watched, label: Text('Vus')),
                ButtonSegment(
                    value: WatchedFilter.unwatched, label: Text('Non vus')),
              ],
              selected: {filter.watched},
              onSelectionChanged: (s) =>
                  notifier.state = filter.copyWith(watched: s.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Possédés uniquement'),
              value: filter.ownedOnly,
              onChanged: (v) =>
                  notifier.state = filter.copyWith(ownedOnly: v),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () =>
                      notifier.state = const CollectionFilter(),
                  child: const Text('Réinitialiser'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
