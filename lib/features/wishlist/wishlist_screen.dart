import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/supabase/view_as.dart';
import '../../data/models/wishlist_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/add_entry_dialogs.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';

/// Écran « Pense-bête » : les titres/saisons gardés pour plus tard. Chaque
/// entrée se convertit en 1-2 clics en visionnage (→ Historique, dialogue
/// date/note) ou en possession (→ Collection, dialogue support/date) — elle
/// quitte alors le pense-bête.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(wishlistStreamProvider);
    final readOnly = ref.watch(isViewingAsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wishlistTitle),
        actions: const [
          OriginalTitleButton(),
          LanguageButton(),
          ThemeToggleButton(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorMessage('$e'))),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.wishlistEmpty, textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(libraryRepositoryProvider).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: items.length,
              itemBuilder: (context, i) =>
                  _WishlistTile(item: items[i], readOnly: readOnly),
            ),
          );
        },
      ),
    );
  }
}

class _WishlistTile extends ConsumerWidget {
  const _WishlistTile({required this.item, required this.readOnly});

  final WishlistView item;
  final bool readOnly;

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// → Historique : dialogue date/note, puis l'entrée quitte le pense-bête.
  Future<void> _toHistory(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<HistChoice>(
      context: context,
      builder: (_) => const AddHistoryDialog(),
    );
    if (res == null || !context.mounted) return;
    final repo = ref.read(libraryRepositoryProvider);
    try {
      await repo.addToHistory(
        item.film,
        season: item.season,
        watchedAt: res.date,
        rating: res.rating,
        comment: res.comment,
      );
      if (item.id != null) await repo.removeFromWishlist(item.id!);
    } catch (e) {
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
    }
  }

  /// → Collection : dialogue support/date, puis l'entrée quitte le pense-bête.
  Future<void> _toCollection(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<CollChoice>(
      context: context,
      builder: (_) => const AddCollectionDialog(),
    );
    if (res == null || !context.mounted) return;
    final repo = ref.read(libraryRepositoryProvider);
    try {
      await repo.addToCollection(
        item.film,
        season: item.season,
        medium: res.medium,
        addedAt: res.date,
      );
      if (item.id != null) await repo.removeFromWishlist(item.id!);
    } catch (e) {
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    if (item.id == null) return;
    try {
      await ref.read(libraryRepositoryProvider).removeFromWishlist(item.id!);
    } catch (e) {
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final film = item.film;
    final title = resolveTitle(
      ref,
      tmdbId: film.tmdbId,
      mediaType: film.mediaType,
      title: film.title,
      originalTitle: film.originalTitle,
    );
    final dateFmt = DateFormat.yMd(Localizations.localeOf(context).toString());

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openMedia(
          context,
          ref,
          type: film.mediaType,
          id: film.tmdbId,
          title: film.title,
          posterPath: film.posterPath,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 52,
                  height: 78,
                  child:
                      PosterImage(posterPath: item.posterPath, size: 'w185'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: title,
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${film.isMovie ? l10n.film : l10n.serie}'
                      '${item.seasonNumber != null ? ' · ${l10n.collSeasonLabel(item.seasonNumber!)}' : ''}'
                      '${film.releaseYear != null ? ' · ${film.releaseYear}' : ''}'
                      '${item.addedAt != null ? ' · ${l10n.wishlistAddedOn(dateFmt.format(item.addedAt!))}' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    if (!readOnly) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _toHistory(context, ref),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: Text(l10n.wishlistToHistory),
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _toCollection(context, ref),
                            icon:
                                const Icon(Icons.video_library, size: 18),
                            label: Text(l10n.wishlistToCollection),
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!readOnly)
                IconButton(
                  tooltip: l10n.wishlistRemoveTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => _remove(context, ref),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
