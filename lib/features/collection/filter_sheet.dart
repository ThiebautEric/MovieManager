import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/film.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../tmdb/tmdb_providers.dart';
import 'collection_filter.dart';

/// Panneau de filtres réutilisable (colonne latérale ou feuille modale) pour les
/// deux vues principales. On lui passe le provider de filtre à éditer, la liste
/// des films présents (pour proposer genres/pays/années réels) et si la note
/// (visionnage) doit être proposée.
class FilterPanel extends ConsumerWidget {
  const FilterPanel({
    super.key,
    required this.filterProvider,
    required this.films,
    required this.showRating,
  });

  final StateProvider<CollectionFilter> filterProvider;
  final List<Film> films;
  final bool showRating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final genresById = ref.watch(genresByIdProvider);
    final favorites = ref.watch(favoritesProvider);

    final presentGenres = <int>{for (final f in films) ...f.genres}.toList()
      ..sort((a, b) => (genresById[a] ?? '').compareTo(genresById[b] ?? ''));
    final presentCountries = <String>{
      for (final f in films)
        if (f.originCountry != null && f.originCountry!.isNotEmpty)
          f.originCountry!
    }.toList()
      ..sort();
    final presentYears = <int>{
      for (final f in films)
        if (f.releaseYear != null) f.releaseYear!
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text('Filtres',
                    style: Theme.of(context).textTheme.titleLarge)),
            if (filter.isActive)
              TextButton(
                onPressed: () => notifier.state = const CollectionFilter(),
                child: const Text('Réinitialiser'),
              ),
          ],
        ),
        const SizedBox(height: 12),
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
          isExpanded: true,
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
        DropdownButtonFormField<String?>(
          isExpanded: true,
          initialValue: filter.country,
          decoration: const InputDecoration(labelText: 'Pays d\'origine'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous')),
            ...presentCountries.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(countryLabel(c)),
                )),
          ],
          onChanged: (v) => notifier.state = v == null
              ? filter.copyWith(clearCountry: true)
              : filter.copyWith(country: v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: filter.year,
          decoration: const InputDecoration(labelText: 'Année'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Toutes')),
            ...presentYears
                .map((y) => DropdownMenuItem(value: y, child: Text('$y'))),
          ],
          onChanged: (v) => notifier.state = v == null
              ? filter.copyWith(clearYear: true)
              : filter.copyWith(year: v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: filter.favoritePersonId,
          decoration: const InputDecoration(labelText: 'Acteur favori'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous')),
            ...favorites.map((p) => DropdownMenuItem(
                  value: p.personId,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: favorites.isEmpty
              ? null
              : (v) => notifier.state = v == null
                  ? filter.copyWith(clearFavorite: true)
                  : filter.copyWith(favoritePersonId: v),
        ),
        if (showRating) ...[
          const SizedBox(height: 8),
          Text('Note minimale du visionnage : '
              '${filter.minRating == 0 ? 'aucune' : filter.minRating.toStringAsFixed(1)}'),
          Slider(
            value: filter.minRating,
            min: 0,
            max: 10,
            divisions: 20,
            label: filter.minRating.toStringAsFixed(1),
            onChanged: (v) => notifier.state = filter.copyWith(minRating: v),
          ),
        ],
      ],
    );
  }
}

/// Largeur minimale pour afficher les filtres en colonne latérale permanente.
const double kFilterBreakpoint = 720;

/// Colonne latérale droite de filtres (toujours affichée sur écran large).
class FilterSidePanel extends StatelessWidget {
  const FilterSidePanel({
    super.key,
    required this.filterProvider,
    required this.films,
    required this.showRating,
  });

  final StateProvider<CollectionFilter> filterProvider;
  final List<Film> films;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: theme.dividerColor)),
        color: theme.colorScheme.surface,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FilterPanel(
          filterProvider: filterProvider,
          films: films,
          showRating: showRating,
        ),
      ),
    );
  }
}

/// Repli modal (écrans étroits) : présente le [FilterPanel] dans une feuille.
class FilterSheet {
  static Future<void> show(
    BuildContext context, {
    required StateProvider<CollectionFilter> filterProvider,
    required List<Film> films,
    bool showRating = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: FilterPanel(
            filterProvider: filterProvider,
            films: films,
            showRating: showRating,
          ),
        ),
      ),
    );
  }
}
