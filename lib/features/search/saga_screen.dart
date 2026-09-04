import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/supabase/view_as.dart';
import '../../core/utils/format.dart';
import '../../data/models/film.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../collection/collection_screen.dart' show HistoryCard;
import '../../data/repositories/favorite_collections_repository.dart';
import '../../tmdb/models/media_summary.dart';
import '../../tmdb/models/tmdb_collection.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/card_title.dart';
import '../../widgets/dark_badge.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../home/detail_app_bar.dart';
import '../home/selected_media.dart';

/// Fiche d'une saga (collection TMDB) : affiche tous les films de la saga avec
/// leur statut possédé / vu, et donc ce qu'il manque. Étoile pour l'ajouter aux
/// favoris. Calquée sur la fiche personne.
class SagaScreen extends ConsumerWidget {
  const SagaScreen({
    super.key,
    required this.collectionId,
    this.embedded = false,
  });

  final int collectionId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionProvider(collectionId));
    final isFav = ref.watch(isFavoriteCollectionProvider(collectionId));
    final data = async.value;
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.sagaTitle),
        leading: DetailLeadingButton(embedded: embedded),
        actions: [
          if (!ref.watch(isViewingAsProvider))
            IconButton(
              tooltip: isFav
                  ? context.l10n.sagaRemoveFavoriteTooltip
                  : context.l10n.sagaAddFavoriteTooltip,
              icon: Icon(isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : null),
              onPressed: data == null
                  ? null
                  : () => ref
                      .read(favoriteCollectionsProvider.notifier)
                      .toggle(
                        collectionId: collectionId,
                        name: data.name,
                        posterPath: data.posterPath,
                      ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(context.l10n.errorMessage(friendlyError(e)))),
        data: (c) => _SagaBody(saga: c),
      ),
    );
  }
}

/// Vue de la liste des films de la saga.
enum _SagaView { collection, history }

class _SagaBody extends ConsumerStatefulWidget {
  const _SagaBody({required this.saga});

  final TmdbCollection saga;

  @override
  ConsumerState<_SagaBody> createState() => _SagaBodyState();
}

class _SagaBodyState extends ConsumerState<_SagaBody> {
  _SagaView _view = _SagaView.collection;

  @override
  Widget build(BuildContext context) {
    final saga = widget.saga;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final collection = ref.watch(collectionStreamProvider).value ?? [];
    final history = ref.watch(historyStreamProvider).value ?? [];

    // Statut par film de la saga (clé TMDB « movie:{id} ») + supports possédés.
    final byKey = <String, _MovieStatus>{};
    final mediumsByKey = <String, List<Medium>>{};
    for (final c in collection) {
      (byKey[c.film.mediaKey] ??= _MovieStatus()).medium ??= c.medium;
      final list = mediumsByKey[c.film.mediaKey] ??= [];
      if (!list.contains(c.medium)) list.add(c.medium);
    }
    for (final v in history) {
      (byKey[v.film.mediaKey] ??= _MovieStatus()).addWatching(v.rating);
    }

    int inLibrary = 0;
    for (final p in saga.parts) {
      final s = byKey['movie:${p.tmdbId}'];
      if (s != null && (s.owned || s.watched)) inLibrary++;
    }

    // Vue courante. Historique = CHAQUE visionnage d'un film de la saga (un film
    // vu N fois → N lignes), du plus récent au plus ancien.
    final history_ = _view == _SagaView.history;
    final partIds = {for (final p in saga.parts) p.tmdbId};
    final sagaHistory = history_
        ? (history
            .where((v) =>
                v.film.mediaType == 'movie' && partIds.contains(v.film.tmdbId))
            .toList()
          ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt)))
        : const <HistoryView>[];
    final sectionTitle = history_
        ? l10n.detailsViewingHistoryTitle(sagaHistory.length)
        : l10n.sagaFilmsSection(saga.parts.length);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PosterImage(
                            posterPath: saga.posterPath, size: 'w342'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(saga.name, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            l10n.sagaOwnedCount(inLibrary, saga.parts.length),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (saga.overview.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(l10n.detailsSynopsis,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(saga.overview),
                ],
                const SizedBox(height: 16),
                SegmentedButton<_SagaView>(
                  segments: [
                    ButtonSegment(
                      value: _SagaView.collection,
                      label: Text(l10n.collectionTitle),
                      icon: const Icon(Icons.grid_view),
                    ),
                    ButtonSegment(
                      value: _SagaView.history,
                      label: Text(l10n.historyTitle),
                      icon: const Icon(Icons.history),
                    ),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _view = s.first),
                ),
                const SizedBox(height: 12),
                Text(sectionTitle, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
        if (history_)
          ..._historySlivers(context, sagaHistory, mediumsByKey)
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: saga.parts.length,
              itemBuilder: (context, i) {
                final p = saga.parts[i];
                return _SagaPartCard(
                  key: ValueKey('movie:${p.tmdbId}'),
                  part: p,
                  status: byKey['movie:${p.tmdbId}'],
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  /// Vue « Historique » : mêmes cartes que l'onglet Historique classique, mais
  /// en LISTE simple (grille), sans séparateurs mois/année. Une carte par
  /// visionnage, du plus récent au plus ancien.
  List<Widget> _historySlivers(
    BuildContext context,
    List<HistoryView> entries,
    Map<String, List<Medium>> mediumsByKey,
  ) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(context.l10n.detailsNoViewings,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
        ),
      ];
    }
    final dateFmt =
        DateFormat.yMd(Localizations.localeOf(context).toString());
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            childAspectRatio: 0.52,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final v = entries[i];
              return HistoryCard(
                key: ValueKey(v.id ??
                    '${v.film.mediaKey}|${v.watchedAt.microsecondsSinceEpoch}'),
                event: v,
                dateLabel: dateFmt.format(v.watchedAt.toLocal()),
                mediums: mediumsByKey[v.film.mediaKey] ?? const [],
                watchedSeasons: const {},
                showBulk: false,
                onTap: () => openMedia(
                  context,
                  ref,
                  type: v.film.mediaType,
                  id: v.film.tmdbId,
                  title: v.film.title,
                  posterPath: v.film.posterPath,
                ),
              );
            },
            childCount: entries.length,
          ),
        ),
      ),
    ];
  }
}

/// Statut d'un film de la saga vis-à-vis de la bibliothèque.
class _MovieStatus {
  Medium? medium;
  bool watched = false;
  final List<double> _ratings = [];

  bool get owned => medium != null;

  double? get rating => _ratings.isEmpty
      ? null
      : _ratings.reduce((a, b) => a + b) / _ratings.length;

  void addWatching(double? rating) {
    watched = true;
    if (rating != null) _ratings.add(rating);
  }
}

/// Carte d'un film de la saga (grille d'affiches) : surbrillance si possédé/vu,
/// sinon « manquant ».
class _SagaPartCard extends ConsumerWidget {
  const _SagaPartCard({super.key, required this.part, required this.status});

  final MediaSummary part;
  final _MovieStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = status;
    final highlight = c != null && (c.owned || c.watched);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openMedia(
        context,
        ref,
        type: 'movie',
        id: part.tmdbId,
        title: part.title,
        posterPath: part.posterPath,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: highlight
                    ? Border.all(color: scheme.primary, width: 3)
                    : null,
                boxShadow: highlight
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.45),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PosterImage(posterPath: part.posterPath),
                    ),
                  ),
                  if (c != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.rating != null) ...[
                            DarkBadge(
                                icon: Icons.star,
                                label: c.rating!.toStringAsFixed(1)),
                            const SizedBox(height: 4),
                          ],
                          if (c.medium != null) ...[
                            MediumBadge(medium: c.medium!),
                            const SizedBox(height: 4),
                          ],
                          if (c.watched && c.rating == null)
                            const DarkBadge(icon: Icons.visibility),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          CardTitle(
            resolveTitle(
              ref,
              tmdbId: part.tmdbId,
              mediaType: 'movie',
              title: part.title,
              originalTitle: part.originalTitle,
              titleIsLocalized: true,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: highlight ? scheme.primary : null,
              fontWeight: highlight ? FontWeight.bold : null,
            ),
          ),
          if (part.releaseYear != null)
            Text('${part.releaseYear}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
