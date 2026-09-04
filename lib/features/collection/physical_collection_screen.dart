import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../core/utils/format.dart';
import '../../data/models/collection_entry.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/account_button.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/keyboard_scroll.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/dark_badge.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../search/details_library_controls.dart';
import 'collection_filter.dart';
import 'filter_sheet.dart';

final _collectionTitleQueryProvider = StateProvider<String>((ref) {
  ref.keepAlive();
  return '';
});

enum _SeenFilter { all, seen, unseen }

/// Critères de tri de la collection. `release*` conservent le regroupement par
/// année ; les autres affichent une grille à plat.
enum _CollectionSort { releaseDesc, releaseAsc, titleAsc, addedDesc, addedAsc }

/// Tri courant, conservé pour la session (keepAlive) comme la recherche titre.
final _collectionSortProvider = StateProvider<_CollectionSort>((ref) {
  ref.keepAlive();
  return _CollectionSort.releaseDesc;
});

String _sortLabel(AppLocalizations l10n, _CollectionSort s) => switch (s) {
      _CollectionSort.releaseDesc => l10n.sortReleaseDesc,
      _CollectionSort.releaseAsc => l10n.sortReleaseAsc,
      _CollectionSort.titleAsc => l10n.sortTitleAsc,
      _CollectionSort.addedDesc => l10n.sortAddedDesc,
      _CollectionSort.addedAsc => l10n.sortAddedAsc,
    };

/// Écran « Collection » : tout ce que l'utilisateur possède (DVD, Blu-ray,
/// Digital), en grille d'affiches. Pour les séries, chaque saison possédée
/// apparaît avec sa propre affiche. Trié par titre puis n° de saison.
class PhysicalCollectionScreen extends ConsumerStatefulWidget {
  const PhysicalCollectionScreen({super.key});

  @override
  ConsumerState<PhysicalCollectionScreen> createState() =>
      _PhysicalCollectionScreenState();
}

class _PhysicalCollectionScreenState
    extends ConsumerState<PhysicalCollectionScreen> {
  late final TextEditingController _titleController;
  Timer? _debounce;
  _SeenFilter _seenFilter = _SeenFilter.all;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: ref.read(_collectionTitleQueryProvider),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  Widget _seenSegment(AppLocalizations l10n) => SegmentedButton<_SeenFilter>(
        segments: [
          ButtonSegment(value: _SeenFilter.all,    label: Text(l10n.filterAll)),
          ButtonSegment(value: _SeenFilter.seen,   label: Text(l10n.filterSeen)),
          ButtonSegment(value: _SeenFilter.unseen, label: Text(l10n.filterUnseen)),
        ],
        selected: {_seenFilter},
        onSelectionChanged: (v) => setState(() => _seenFilter = v.first),
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 11),
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );

  void _onTitleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(_collectionTitleQueryProvider.notifier).state =
          value.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMd(locale);
    final async = ref.watch(collectionStreamProvider);
    final filter = ref.watch(collectionFilterProvider);
    final entries = ref.watch(filteredCollectionProvider);
    final titleQuery = ref.watch(_collectionTitleQueryProvider);
    final sort = ref.watch(_collectionSortProvider);
    final films = [for (final c in (async.value ?? const <CollectionView>[])) c.film];
    final ratingBySeason = ref.watch(ratingByKeySeasonProvider);
    final wide = MediaQuery.of(context).size.width >= kFilterBreakpoint;

    // Clés des films déjà visionnés (pour le filtre Vus / Non vus).
    final watchedKeys = {
      for (final v in ref.watch(historyStreamProvider).value ?? const <HistoryView>[])
        v.film.mediaKey
    };

    // Filtre texte appliqué après les autres filtres.
    final textFiltered = titleQuery.isEmpty
        ? entries
        : entries.where((e) {
            final q = titleQuery;
            return e.film.title.toLowerCase().contains(q) ||
                (e.film.originalTitle?.toLowerCase().contains(q) ?? false);
          }).toList();

    final displayedEntries = switch (_seenFilter) {
      _SeenFilter.all => textFiltered,
      _SeenFilter.seen =>
        textFiltered.where((e) => watchedKeys.contains(e.film.mediaKey)).toList(),
      _SeenFilter.unseen =>
        textFiltered.where((e) => !watchedKeys.contains(e.film.mediaKey)).toList(),
    };

    // Année effective d'une entrée : TMDB (keepAlive, un seul appel par série/saison).
    int? effectiveYear(CollectionView e) {
      if (e.film.isMovie) return e.film.releaseYear;
      if (e.episodeNumber != null && e.seasonNumber != null) {
        final eps = ref
            .watch(seasonEpisodesProvider(
                (id: e.film.tmdbId, season: e.seasonNumber!)))
            .value;
        final ep = eps
            ?.where((ep) => ep.episodeNumber == e.episodeNumber)
            .firstOrNull;
        if (ep?.airYear != null) return ep!.airYear;
      }
      final details = ref
          .watch(
              mediaDetailsProvider((id: e.film.tmdbId, type: e.film.mediaType)))
          .value;
      if (details != null && e.seasonNumber != null) {
        final season = details.seasons
            .where((s) => s.seasonNumber == e.seasonNumber)
            .firstOrNull;
        if (season?.year != null) return season!.year;
      }
      return e.film.releaseYear;
    }

    // Durée effective : stockée en priorité, puis fallback TMDB.
    // Saison (tous épisodes) → épisode individuel en dernier recours (saison 0).
    int? effectiveRuntime(CollectionView e) {
      final stored = e.totalMinutes;
      if (stored != null) return stored;
      if (e.episodeNumber != null && e.seasonNumber != null) {
        final eps = ref
            .watch(seasonEpisodesProvider(
                (id: e.film.tmdbId, season: e.seasonNumber!)))
            .value;
        final rt = eps
            ?.where((ep) => ep.episodeNumber == e.episodeNumber)
            .firstOrNull
            ?.runtime;
        if (rt != null) return rt;
        // Fallback : endpoint épisode individuel (spéciaux / saison 0 sans
        // runtime dans l'endpoint saison).
        return ref
            .watch(episodeRuntimeProvider((
              id: e.film.tmdbId,
              season: e.seasonNumber!,
              episode: e.episodeNumber!,
            )))
            .value;
      }
      return null;
    }

    final theme = Theme.of(context);

    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: TextField(
        controller: _titleController,
        onChanged: _onTitleChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: l10n.collectionSearchHint,
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 18),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: titleQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _titleController.clear();
                    _onTitleChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );

    final content = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(friendlyError(e)))),
      data: (_) {
        if (displayedEntries.isEmpty) {
          return Column(
            children: [
              searchBar,
              Expanded(child: EmptyState(message: l10n.collEmpty)),
            ],
          );
        }

        // Clé stable même sans id (entrées non synchronisées / import) : sinon
        // toutes les lignes id==null partagent le bucket `null` et héritent des
        // valeurs de la dernière insérée.
        String cacheKey(CollectionView e) =>
            e.id ??
            '${e.film.mediaKey}|${e.seasonNumber}|${e.episodeNumber}|${e.medium.name}';

        // Pré-calcul des années et durées — évite d'appeler ref.watch dans le
        // comparateur de sort (O(n log n) appels) et dans les builders de grille.
        final yearCache = <String, int?>{
          for (final e in displayedEntries) cacheKey(e): effectiveYear(e),
        };
        final runtimeCache = <String, int?>{
          for (final e in displayedEntries) cacheKey(e): effectiveRuntime(e),
        };
        // Titre AFFICHÉ selon le mode de titre courant (VO / EN / traduit) —
        // sert au tri alphabétique ET à l'affichage, pour que l'ordre suive la
        // langue du titre choisie. resolveTitle fait des ref.watch, d'où le
        // pré-calcul hors comparateur.
        final titleCache = <String, String>{
          for (final e in displayedEntries)
            cacheKey(e): resolveTitle(
              ref,
              tmdbId: e.film.tmdbId,
              mediaType: e.film.mediaType,
              title: e.film.title,
              originalTitle: e.film.originalTitle,
            ),
        };

        // Départage commun : titre (insensible à la casse), puis saison, puis
        // épisode — pour un ordre stable à valeur de tri principale égale.
        int titleTie(CollectionView a, CollectionView b) {
          final t = (titleCache[cacheKey(a)] ?? '')
              .toLowerCase()
              .compareTo((titleCache[cacheKey(b)] ?? '').toLowerCase());
          if (t != 0) return t;
          final s = (a.seasonNumber ?? -1).compareTo(b.seasonNumber ?? -1);
          if (s != 0) return s;
          return (a.episodeNumber ?? -1).compareTo(b.episodeNumber ?? -1);
        }

        // Année de sortie (valeurs nulles en dernier).
        int byYear(CollectionView a, CollectionView b, bool desc) {
          final ay = yearCache[cacheKey(a)];
          final by = yearCache[cacheKey(b)];
          if (ay == null && by == null) return titleTie(a, b);
          if (ay == null) return 1;
          if (by == null) return -1;
          if (ay != by) return desc ? by.compareTo(ay) : ay.compareTo(by);
          return titleTie(a, b);
        }

        // Date d'ajout à la collection (valeurs nulles en dernier).
        int byAdded(CollectionView a, CollectionView b, bool desc) {
          final aa = a.addedAt;
          final bb = b.addedAt;
          if (aa == null && bb == null) return titleTie(a, b);
          if (aa == null) return 1;
          if (bb == null) return -1;
          final c = desc ? bb.compareTo(aa) : aa.compareTo(bb);
          return c != 0 ? c : titleTie(a, b);
        }

        final Comparator<CollectionView> comparator = switch (sort) {
          _CollectionSort.releaseDesc => (a, b) => byYear(a, b, true),
          _CollectionSort.releaseAsc => (a, b) => byYear(a, b, false),
          _CollectionSort.titleAsc => titleTie,
          _CollectionSort.addedDesc => (a, b) => byAdded(a, b, true),
          _CollectionSort.addedAsc => (a, b) => byAdded(a, b, false),
        };
        final sorted = [...displayedEntries]..sort(comparator);

        // Le regroupement par année n'a de sens que pour les tris par sortie.
        final groupByYear = sort == _CollectionSort.releaseDesc ||
            sort == _CollectionSort.releaseAsc;

        const grid = SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 0.52,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        );

        Widget buildCard(CollectionView entry) {
          final totalMin = runtimeCache[cacheKey(entry)];
          final duration = totalMin != null ? fmtDuration(totalMin) : null;
          return _CollectionCard(
            poster: entry.posterPath,
            title: titleCache[cacheKey(entry)] ?? entry.film.title,
            year: yearCache[cacheKey(entry)],
            duration: duration,
            subtitle: entry.episodeNumber != null
                ? 'S${entry.seasonNumber}E${entry.episodeNumber} · ${resolveEpisodeName(ref, tmdbId: entry.film.tmdbId, seasonNumber: entry.seasonNumber, episodeNumber: entry.episodeNumber!, stored: null)}'
                : entry.seasonNumber != null
                    ? l10n.collSeasonLabel(entry.seasonNumber!)
                    : entry.film.isMovie
                        ? l10n.film
                        : l10n.serie,
            badge: MediumBadge(medium: entry.medium),
            seasonNumber: entry.seasonNumber,
            dateLabel: entry.addedAt != null
                ? dateFmt.format(entry.addedAt!.toLocal())
                : null,
            rating: ratingBySeason[
                '${entry.film.mediaKey}|${entry.seasonNumber}'],
            onTap: () => openEntry(
              context,
              ref,
              tmdbId: entry.film.tmdbId,
              mediaType: entry.film.mediaType,
              title: entry.film.title,
              posterPath: entry.film.posterPath,
              seasonNumber: entry.seasonNumber,
              episodeNumber: entry.episodeNumber,
            ),
          );
        }

        SliverPadding gridSliver(List<CollectionView> items) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              sliver: SliverGrid(
                gridDelegate: grid,
                delegate: SliverChildBuilderDelegate(
                  (context, i) => buildCard(items[i]),
                  childCount: items.length,
                ),
              ),
            );

        final slivers = <Widget>[
          SliverToBoxAdapter(child: searchBar),
        ];
        if (groupByYear) {
          // Regroupement par année (sorted est déjà ordonné).
          final groups = <({int? year, List<CollectionView> items})>[];
          for (final e in sorted) {
            final y = yearCache[cacheKey(e)];
            if (groups.isEmpty || groups.last.year != y) {
              groups.add((year: y, items: [e]));
            } else {
              groups.last.items.add(e);
            }
          }
          for (final g in groups) {
            slivers.add(SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  g.year?.toString() ?? '—',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ));
            slivers.add(gridSliver(g.items));
          }
        } else {
          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
          slivers.add(gridSliver(sorted));
        }
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));

        return KeyboardScroll(
          builder: (ctrl) => RefreshIndicator(
            onRefresh: () => ref.read(libraryRepositoryProvider).refresh(),
            child: CustomScrollView(controller: ctrl, slivers: slivers),
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: wide
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBarTitle(l10n.collectionTitle),
                  const SizedBox(width: 12),
                  _seenSegment(l10n),
                ],
              )
            : AppBarTitle(l10n.collectionTitle),
        bottom: wide
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _seenSegment(l10n),
                  ),
                ),
              ),
        actions: [
          PopupMenuButton<_CollectionSort>(
            tooltip: l10n.sortTooltip,
            icon: const Icon(Icons.sort),
            initialValue: sort,
            onSelected: (v) =>
                ref.read(_collectionSortProvider.notifier).state = v,
            itemBuilder: (_) => [
              for (final opt in _CollectionSort.values)
                CheckedPopupMenuItem(
                  value: opt,
                  checked: opt == sort,
                  child: Text(_sortLabel(l10n, opt)),
                ),
            ],
          ),
          if (!wide)
            IconButton(
              tooltip: l10n.filterTooltip,
              icon: Badge(
                isLabelVisible: filter.isActive,
                child: const Icon(Icons.filter_list),
              ),
              onPressed: () => FilterSheet.show(
                context,
                filterProvider: collectionFilterProvider,
                films: films,
              ),
            ),
          const OriginalTitleButton(),
          const LanguageButton(),
          const ThemeToggleButton(),
          const AccountButton(),
        ],
      ),
      body: wide
          ? Row(
              children: [
                Expanded(child: content),
                FilterSidePanel(
                  filterProvider: collectionFilterProvider,
                  films: films,
                  showRating: false,
                ),
              ],
            )
          : content,
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.poster,
    required this.title,
    required this.year,
    required this.subtitle,
    required this.badge,
    required this.seasonNumber,
    required this.dateLabel,
    required this.onTap,
    this.duration,
    this.rating,
  });

  final String? poster;
  final String title;
  final int? year;
  final String? duration;
  final String subtitle;
  final Widget badge;
  final int? seasonNumber;
  final String? dateLabel;
  final VoidCallback onTap;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PosterImage(posterPath: poster),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rating != null) ...[
                        DarkBadge(
                            icon: Icons.star,
                            label: rating!.toStringAsFixed(1)),
                        const SizedBox(height: 4),
                      ],
                      badge,
                      if (seasonNumber != null) ...[
                        const SizedBox(height: 4),
                        _chip(Icons.live_tv, 'S$seasonNumber'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: title,
              style: theme.textTheme.bodyMedium,
              children: [
                if (year != null)
                  TextSpan(
                    text: '  ($year)',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                if (duration != null)
                  TextSpan(
                    text: '  $duration',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(subtitle, style: theme.textTheme.bodySmall),
          if (dateLabel != null)
            Row(
              children: [
                Icon(Icons.event_available,
                    size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dateLabel!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 2),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
