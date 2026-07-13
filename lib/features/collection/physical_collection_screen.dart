import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../data/models/collection_entry.dart';
import '../../data/repositories/collection_repository.dart';
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

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionStreamProvider);
    final filter = ref.watch(collectionFilterProvider);
    final entries = ref.watch(filteredCollectionProvider);
    final films = [for (final c in (async.value ?? const <CollectionView>[])) c.film];
    final wide = MediaQuery.of(context).size.width >= kFilterBreakpoint;

    final content = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (_) {
        if (entries.isEmpty) {
          return const _EmptyState(
            message:
                'Aucun titre dans ta collection.\nSur une fiche, ajoute un support (DVD, Blu-ray ou Digital), ou ajuste les filtres.',
          );
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
                title: entry.film.title,
                subtitle: (entry.seasonNumber != null
                        ? 'Saison ${entry.seasonNumber}'
                        : '${entry.film.isMovie ? 'Film' : 'Série'}'
                            '${entry.film.releaseYear != null ? ' · ${entry.film.releaseYear}' : ''}') +
                    (duration != null ? ' · $duration' : ''),
                badge: MediumBadge(medium: entry.medium),
                seasonNumber: entry.seasonNumber,
                dateLabel:
                    entry.addedAt != null ? _fmtDate(entry.addedAt!) : null,
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
        title: const Text('Collection'),
        actions: [
          if (!wide)
            IconButton(
              tooltip: 'Filtrer',
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
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium),
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
