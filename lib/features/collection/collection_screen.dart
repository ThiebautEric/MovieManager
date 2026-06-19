import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/collection_item.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';
import 'collection_filter.dart';
import 'filter_sheet.dart';

/// Écran de la collection personnelle (grille filtrable).
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionStreamProvider);
    final filter = ref.watch(collectionFilterProvider);
    final filtered = ref.watch(filteredCollectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma collection'),
        actions: [
          IconButton(
            tooltip: 'Filtrer',
            icon: Badge(
              isLabelVisible: filter.isActive,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => FilterSheet.show(context),
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (all) {
          if (all.isEmpty) {
            return const _EmptyState(
              message:
                  'Votre collection est vide.\nUtilisez la recherche pour ajouter des films.',
            );
          }
          if (filtered.isEmpty) {
            return const _EmptyState(
                message: 'Aucun item ne correspond aux filtres.');
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(collectionRepositoryProvider).refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.52,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final item = filtered[i];
                return _CollectionCard(
                  item: item,
                  onTap: () => openMedia(
                    context,
                    ref,
                    type: item.mediaType,
                    id: item.tmdbId,
                    title: item.title,
                    posterPath: item.posterPath,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.item, required this.onTap});

  final CollectionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                    child: PosterImage(posterPath: item.posterPath),
                  ),
                ),
                if (item.watched)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _badge(context, Icons.visibility, 'Vu'),
                  ),
                if (item.userRating != null)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: _badge(context, Icons.star,
                        item.userRating!.toStringAsFixed(1)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium),
          if (item.releaseYear != null)
            Text('${item.releaseYear}',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, IconData icon, String label) {
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
