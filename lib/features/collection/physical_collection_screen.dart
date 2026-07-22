import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/utils/format.dart';
import '../../data/models/collection_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/card_title.dart';
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
    final wide = MediaQuery.of(context).size.width >= kFilterBreakpoint;

    final content = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage('$e'))),
      data: (_) {
        if (entries.isEmpty) {
          return _EmptyState(message: l10n.collEmpty);
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(libraryRepositoryProvider).refresh(),
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.52,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              // Durée : film, ou cumul de la saison (« ≈ » si estimé).
              final duration = entry.totalMinutes != null
                  ? '${entry.isExactDuration ? '' : '≈'}${fmtDuration(entry.totalMinutes!)}'
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
                subtitle: (entry.seasonNumber != null
                        ? l10n.collSeasonLabel(entry.seasonNumber!)
                        : '${entry.film.isMovie ? l10n.film : l10n.serie}'
                            '${entry.film.releaseYear != null ? ' · ${entry.film.releaseYear}' : ''}') +
                    (duration != null ? ' · $duration' : ''),
                badge: MediumBadge(medium: entry.medium),
                seasonNumber: entry.seasonNumber,
                dateLabel: entry.addedAt != null
                    ? dateFmt.format(entry.addedAt!)
                    : null,
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
    required this.subtitle,
    required this.badge,
    required this.seasonNumber,
    required this.dateLabel,
    required this.onTap,
  });

  final String? poster;
  final String title;
  final String subtitle;
  final Widget badge;
  final int? seasonNumber;
  final String? dateLabel;
  final VoidCallback onTap;

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
                Positioned(top: 6, left: 6, child: badge),
                if (seasonNumber != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _chip(Icons.live_tv, 'S$seasonNumber'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          CardTitle(title, style: theme.textTheme.bodyMedium),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
