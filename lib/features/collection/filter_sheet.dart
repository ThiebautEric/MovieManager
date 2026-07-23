import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/l10n/l10n.dart';
import '../../data/models/film.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/tmdb_badge.dart';
import '../../widgets/yellow_frame_logo.dart';
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

  static String _ratingLabel(double r) {
    final i = r.round();
    return r == i.toDouble() ? '$i ★' : '${r.toStringAsFixed(1)} ★';
  }

  Widget _buildRatingDropdown(
    BuildContext context,
    WidgetRef ref,
    CollectionFilter filter,
    StateController<CollectionFilter> notifier,
    AppLocalizations l10n,
  ) {
    final history = ref.watch(historyStreamProvider).value ?? [];
    final ratingKeys = <double, Set<String>>{};
    final unratedKeys = <String>{};
    for (final v in history) {
      if (v.rating != null) {
        (ratingKeys[v.rating!] ??= {}).add(v.film.mediaKey);
      } else {
        unratedKeys.add(v.film.mediaKey);
      }
    }
    final presentRatings = ratingKeys.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return DropdownButtonFormField<double?>(
      isExpanded: true,
      initialValue: filter.rating,
      decoration: InputDecoration(labelText: l10n.filterRating),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
        ...presentRatings.map((e) => DropdownMenuItem(
              value: e.key,
              child: Text('${_ratingLabel(e.key)}  (${e.value.length})'),
            )),
        if (unratedKeys.isNotEmpty)
          DropdownMenuItem(
            value: -1,
            child: Text('${l10n.filterRatingNone}  (${unratedKeys.length})'),
          ),
      ],
      onChanged: (v) => notifier.state = v == null
          ? filter.copyWith(clearRating: true)
          : filter.copyWith(rating: v),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final genresById = ref.watch(genresByIdProvider);
    final favorites = ref.watch(favoritesProvider);

    // Pour chaque facette, on compte les films distincts (par mediaKey).
    final genreKeys = <int, Set<String>>{};
    final countryKeys = <String, Set<String>>{};
    final yearKeys = <int, Set<String>>{};
    for (final f in films) {
      final k = f.mediaKey;
      for (final g in f.genres) {
        (genreKeys[g] ??= {}).add(k);
      }
      final c = f.originCountry;
      if (c != null && c.isNotEmpty) (countryKeys[c] ??= {}).add(k);
      if (f.releaseYear != null) (yearKeys[f.releaseYear!] ??= {}).add(k);
    }
    final presentGenres = genreKeys.entries.toList()
      ..sort((a, b) =>
          (genresById[a.key] ?? '').compareTo(genresById[b.key] ?? ''));
    final presentCountries = countryKeys.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final presentYears = yearKeys.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(l10n.filterTitle,
                    style: Theme.of(context).textTheme.titleLarge)),
            if (filter.isActive)
              TextButton(
                onPressed: () => notifier.state = const CollectionFilter(),
                child: Text(l10n.filterReset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.filterType),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.filterAll),
              selected: filter.mediaType == null,
              onSelected: (_) =>
                  notifier.state = filter.copyWith(clearMediaType: true),
            ),
            ChoiceChip(
              label: Text(l10n.filterFilms),
              selected: filter.mediaType == 'movie',
              onSelected: (_) =>
                  notifier.state = filter.copyWith(mediaType: 'movie'),
            ),
            ChoiceChip(
              label: Text(l10n.filterSeries),
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
          decoration: InputDecoration(labelText: l10n.filterGenre),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
            ...presentGenres.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                      '${genresById[e.key] ?? l10n.filterGenreFallback(e.key)} (${e.value.length})'),
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
          decoration: InputDecoration(labelText: l10n.filterCountry),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
            ...presentCountries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text('${countryLabel(e.key)} (${e.value.length})'),
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
          decoration: InputDecoration(labelText: l10n.filterYear),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.filterAllFeminine)),
            ...presentYears.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.key} (${e.value.length})'),
                )),
          ],
          onChanged: (v) => notifier.state = v == null
              ? filter.copyWith(clearYear: true)
              : filter.copyWith(year: v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: filter.favoritePersonId,
          decoration: InputDecoration(labelText: l10n.filterFavoriteActor),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
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
          const SizedBox(height: 16),
          _buildRatingDropdown(context, ref, filter, notifier, l10n),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo au-dessus des filtres (visible en mode large / web).
            const Center(child: TmdbBadge(height: 22)),
            const SizedBox(height: 16),
            const Center(child: YellowFrameLogo(width: 150)),
            const SizedBox(height: 24),
            FilterPanel(
              filterProvider: filterProvider,
              films: films,
              showRating: showRating,
            ),
          ],
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
