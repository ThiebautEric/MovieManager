import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../core/utils/format.dart';
import '../../data/models/collection_entry.dart';
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
import '../home/selected_media.dart';
import 'collection_filter.dart';
import 'filter_sheet.dart';

/// Écran « Collection » : tout ce que l'utilisateur possède (DVD, Blu-ray,
/// Digital), en grille d'affiches. Pour les séries, chaque saison possédée
/// apparaît avec sa propre affiche. Trié par titre puis n° de saison.
class PhysicalCollectionScreen extends ConsumerWidget {
  const PhysicalCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMd(locale);
    final async = ref.watch(collectionStreamProvider);
    final filter = ref.watch(collectionFilterProvider);
    final entries = ref.watch(filteredCollectionProvider);
    final films = [for (final c in (async.value ?? const <CollectionView>[])) c.film];
    final ratingBySeason = ref.watch(ratingByKeySeasonProvider);
    final wide = MediaQuery.of(context).size.width >= kFilterBreakpoint;

    // Année effective d'une entrée : valeur stockée en base (rapide) ou TMDB.
    int? effectiveYear(CollectionView e) {
      if (e.film.isMovie) return e.film.releaseYear;
      // Valeurs pré-calculées stockées dans la collection (backfill v9).
      if (e.episodeAirYear != null) return e.episodeAirYear;
      if (e.seasonAirYear != null) return e.seasonAirYear;
      // Fallback TMDB (entrées antérieures au backfill).
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

    final content = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(friendlyError(e)))),
      data: (_) {
        if (entries.isEmpty) {
          return EmptyState(message: l10n.collEmpty);
        }

        // Tri : année desc, titre asc, saison asc, épisode asc.
        final sorted = [...entries]
          ..sort((a, b) {
            final ay = effectiveYear(a);
            final by = effectiveYear(b);
            if (ay == null && by == null) {
              final t = a.film.title.compareTo(b.film.title);
              if (t != 0) return t;
              final s = (a.seasonNumber ?? -1).compareTo(b.seasonNumber ?? -1);
              if (s != 0) return s;
              return (a.episodeNumber ?? -1).compareTo(b.episodeNumber ?? -1);
            }
            if (ay == null) return 1;
            if (by == null) return -1;
            if (ay != by) return by.compareTo(ay);
            final t = a.film.title.compareTo(b.film.title);
            if (t != 0) return t;
            final s = (a.seasonNumber ?? -1).compareTo(b.seasonNumber ?? -1);
            if (s != 0) return s;
            return (a.episodeNumber ?? -1).compareTo(b.episodeNumber ?? -1);
          });

        // Regroupement par année.
        final groups = <({int? year, List<CollectionView> items})>[];
        for (final e in sorted) {
          final y = effectiveYear(e);
          if (groups.isEmpty || groups.last.year != y) {
            groups.add((year: y, items: [e]));
          } else {
            groups.last.items.add(e);
          }
        }

        const grid = SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 0.52,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        );

        final slivers = <Widget>[];
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
          slivers.add(SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            sliver: SliverGrid(
              gridDelegate: grid,
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final entry = g.items[i];
                  // Durée : stockée en base → somme épisodes TMDB → runtime×count.
                  int? totalMin = entry.totalMinutes;
                  bool exact = entry.isExactDuration;
                  if (totalMin == null && entry.seasonNumber != null) {
                    // Fallback 1 : somme des runtimes d'épisodes TMDB.
                    final eps = ref
                        .watch(seasonEpisodesProvider(
                            (id: entry.film.tmdbId,
                             season: entry.seasonNumber!)))
                        .value;
                    if (eps != null && eps.isNotEmpty) {
                      if (entry.episodeNumber != null) {
                        totalMin = eps
                            .where((e) => e.episodeNumber == entry.episodeNumber)
                            .firstOrNull
                            ?.runtime;
                      } else {
                        final sum = eps.fold<int>(
                            0, (acc, e) => acc + (e.runtime ?? 0));
                        if (sum > 0) { totalMin = sum; exact = true; }
                      }
                    }
                    // Fallback 2 : runtime typique × nb épisodes (mediaDetails).
                    if (totalMin == null && entry.episodeNumber == null) {
                      final details = ref
                          .watch(mediaDetailsProvider(
                              (id: entry.film.tmdbId,
                               type: entry.film.mediaType)))
                          .value;
                      final rt = details?.runtime;
                      final season = details?.seasons
                          .where((s) => s.seasonNumber == entry.seasonNumber)
                          .firstOrNull;
                      final count = season?.episodeCount;
                      if (rt != null && rt > 0 && count != null && count > 0) {
                        totalMin = rt * count;
                        exact = false;
                      }
                    }
                  }
                  final duration = totalMin != null
                      ? '${exact ? '' : '≈'}${fmtDuration(totalMin)}'
                      : null;
                  return _CollectionCard(
                    poster: entry.posterPath,
                    title: resolveTitle(
                      ref,
                      tmdbId: entry.film.tmdbId,
                      mediaType: entry.film.mediaType,
                      title: entry.film.title,
                      originalTitle: entry.film.originalTitle,
                    ),
                    year: effectiveYear(entry),
                    subtitle: (entry.episodeNumber != null
                            ? 'S${entry.seasonNumber}E${entry.episodeNumber} · ${resolveEpisodeName(ref, tmdbId: entry.film.tmdbId, seasonNumber: entry.seasonNumber!, episodeNumber: entry.episodeNumber!, stored: null)}'
                            : entry.seasonNumber != null
                                ? l10n.collSeasonLabel(entry.seasonNumber!)
                                : entry.film.isMovie
                                    ? l10n.film
                                    : l10n.serie) +
                        (duration != null ? ' · $duration' : ''),
                    badge: MediumBadge(medium: entry.medium),
                    seasonNumber: entry.seasonNumber,
                    dateLabel: entry.addedAt != null
                        ? dateFmt.format(entry.addedAt!.toLocal())
                        : null,
                    rating: ratingBySeason[
                        '${entry.film.mediaKey}|${entry.seasonNumber}'],
                    onTap: () => openMedia(
                      context,
                      ref,
                      type: entry.film.mediaType,
                      id: entry.film.tmdbId,
                      title: entry.film.title,
                      posterPath: entry.film.posterPath,
                    ),
                  );
                },
                childCount: g.items.length,
              ),
            ),
          ));
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
        title: AppBarTitle(l10n.collectionTitle),
        actions: [
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
    this.rating,
  });

  final String? poster;
  final String title;
  final int? year;
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

