import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/supabase/view_as.dart';
import '../../core/utils/format.dart';
import '../../data/models/collection_entry.dart';
import '../../data/models/film.dart';
import '../../data/models/film_season.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../tmdb/models/media_details.dart';
import '../../tmdb/models/season_episodes.dart';
import '../../widgets/add_entry_dialogs.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import 'details_episode_picker.dart';

void _toast(BuildContext context, String msg) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action)),
      ],
    ),
  );
  return res == true;
}

/// Deux sections INDÉPENDANTES : la collection (possessions) et l'historique
/// (visionnages). Pour les séries, suivi par saison avec `ExpansionTile`.
class LibraryControls extends ConsumerWidget {
  const LibraryControls({super.key, required this.details});

  final MediaDetails details;

  bool get _isSeries => details.mediaType == 'tv' && details.seasons.isNotEmpty;

  Film get _film => Film.fromDetails(details);

  FilmSeason? _season(int? n) {
    if (n == null) return null;
    for (final s in details.seasons) {
      if (s.seasonNumber == n) return FilmSeason.fromInfo(s);
    }
    return FilmSeason(seasonNumber: n);
  }

  String _scopeLabel(BuildContext context, int? season) => season == null
      ? (details.mediaType == 'movie'
          ? context.l10n.film
          : context.l10n.detailsWholeSeries)
      : context.l10n.detailsSeasonNumber(season);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(libraryRepositoryProvider);
    final readOnly = ref.watch(isViewingAsProvider);
    final key = '${details.mediaType}:${details.tmdbId}';
    final collection = (ref.watch(collectionStreamProvider).value ?? [])
        .where((c) => c.film.mediaKey == key)
        .toList();
    final history = (ref.watch(historyStreamProvider).value ?? [])
        .where((h) => h.film.mediaKey == key)
        .toList();

    if (!_isSeries) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!readOnly) ...[
            _WishlistButton(film: _film, season: null),
            const SizedBox(height: 8),
          ],
          _CollectionSection(
            entries: collection,
            isSeries: false,
            scopeLabel: (n) => _scopeLabel(context, n),
            readOnly: readOnly,
            onAdd: () => _addCollection(context, repo, season: null),
            onRemove: (id) => _confirmRemoveCollection(context, repo, id),
          ),
          const SizedBox(height: 12),
          _HistorySection(
            entries: history,
            isSeries: false,
            scopeLabel: (n) => _scopeLabel(context, n),
            readOnly: readOnly,
            onAdd: () => _addHistory(context, repo, season: null),
            onEdit: (e) => _editHistory(context, repo, e),
            onRemove: (id) => _confirmRemoveHistory(context, repo, id),
          ),
        ],
      );
    }

    final collBySeason = <int, List<CollectionView>>{};
    for (final c in collection) {
      if (c.seasonNumber != null) {
        (collBySeason[c.seasonNumber!] ??= []).add(c);
      }
    }
    final histBySeason = <int, List<HistoryView>>{};
    for (final h in history) {
      if (h.seasonNumber != null) {
        (histBySeason[h.seasonNumber!] ??= []).add(h);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(context.l10n.detailsSeasonsTitle,
              style: theme.textTheme.titleMedium),
        ),
        Text(
          context.l10n.detailsSeasonsHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 8),
        for (final s in details.seasons)
          _seasonTile(
            context,
            repo,
            s,
            collBySeason[s.seasonNumber] ?? const [],
            histBySeason[s.seasonNumber] ?? const [],
            readOnly: readOnly,
          ),
      ],
    );
  }

  Widget _seasonTile(
    BuildContext context,
    LibraryRepository repo,
    SeasonInfo info,
    List<CollectionView> coll,
    List<HistoryView> hist, {
    required bool readOnly,
  }) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final title = info.name.isNotEmpty
        ? info.name
        : l10n.detailsSeasonNumber(info.seasonNumber);
    final meta = [
      if (info.episodeCount > 0) l10n.detailsEpisodeCount(info.episodeCount),
      if (info.year != null) '${info.year}',
    ].join(' · ');
    final summary = (coll.isEmpty && hist.isEmpty)
        ? l10n.detailsSeasonNotTracked
        : '${l10n.detailsMediaCount(coll.length)} · ${l10n.detailsViewingCount(hist.length)}';

    String? seasonRating;
    if (hist.isNotEmpty && hist.every((h) => h.rating != null)) {
      final avg = hist.map((h) => h.rating!).reduce((a, b) => a + b) / hist.length;
      seasonRating = avg.toStringAsFixed(1);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        leading: SizedBox(
          width: 46,
          height: 69,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: PosterImage(posterPath: info.posterPath, size: 'w185'),
          ),
        ),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(
          [
            if (meta.isNotEmpty) meta,
            summary,
            if (seasonRating != null) '★ $seasonRating/10',
          ].join('\n'),
          style: theme.textTheme.bodySmall,
        ),
        children: [
          if (!readOnly) ...[
            _WishlistButton(film: _film, season: _season(info.seasonNumber)),
            const SizedBox(height: 4),
          ],
          _CollectionSection(
            entries: coll,
            isSeries: true,
            scopeLabel: (n) => _scopeLabel(context, n),
            readOnly: readOnly,
            onAdd: () => _addCollection(context, repo, season: info.seasonNumber),
            onRemove: (id) => _confirmRemoveCollection(context, repo, id),
          ),
          const SizedBox(height: 8),
          _HistorySection(
            entries: hist,
            isSeries: true,
            scopeLabel: (n) => _scopeLabel(context, n),
            readOnly: readOnly,
            onAdd: () => _addHistory(context, repo, season: info.seasonNumber),
            onEdit: (e) => _editHistory(context, repo, e),
            onRemove: (id) => _confirmRemoveHistory(context, repo, id),
          ),
          if (!readOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _rateEpisode(context, repo, info, hist),
                icon: const Icon(Icons.live_tv, size: 18),
                label: Text(l10n.detailsRateEpisode),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _rateEpisode(BuildContext context, LibraryRepository repo,
      SeasonInfo info, List<HistoryView> hist) async {
    final ep = await showDialog<EpisodeInfo>(
      context: context,
      builder: (_) => EpisodePickerDialog(
        tmdbId: details.tmdbId,
        seasonNumber: info.seasonNumber,
        watched: {
          for (final h in hist)
            if (h.episodeNumber != null) h.episodeNumber!,
        },
      ),
    );
    if (ep == null || !context.mounted) return;
    final res = await showDialog<HistChoice>(
      context: context,
      builder: (_) => AddHistoryDialog(
        title: ep.name.isEmpty ? 'E${ep.episodeNumber}' : ep.name,
        header: EpisodeHeader(episode: ep),
      ),
    );
    if (res == null) return;
    try {
      await repo.addToHistory(
        _film,
        season: _season(info.seasonNumber),
        episodeNumber: ep.episodeNumber,
        episodeName: ep.name.isEmpty ? null : ep.name,
        episodeRuntime: ep.runtime,
        watchedAt: res.date,
        rating: res.rating,
        comment: res.comment,
      );
    } catch (e) {
      if (context.mounted) _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }

  Future<void> _addCollection(BuildContext context, LibraryRepository repo,
      {required int? season}) async {
    final res = await showDialog<CollChoice>(
      context: context,
      builder: (_) => const AddCollectionDialog(),
    );
    if (res == null) return;
    try {
      await repo.addToCollection(
        _film,
        season: _season(season),
        medium: res.medium,
        addedAt: res.date,
      );
    } catch (e) {
      if (context.mounted) _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }

  Future<void> _addHistory(BuildContext context, LibraryRepository repo,
      {required int? season}) async {
    final res = await showDialog<HistChoice>(
      context: context,
      builder: (_) => const AddHistoryDialog(),
    );
    if (res == null) return;
    try {
      await repo.addToHistory(
        _film,
        season: _season(season),
        watchedAt: res.date,
        rating: res.rating,
        comment: res.comment,
      );
    } catch (e) {
      if (context.mounted) _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }

  Future<void> _editHistory(
      BuildContext context, LibraryRepository repo, HistoryView e) async {
    final res = await showDialog<HistChoice>(
      context: context,
      builder: (_) => AddHistoryDialog(
        initialDate: e.watchedAt,
        initialRating: e.rating,
        initialComment: e.comment,
        title: context.l10n.detailsEditViewing,
      ),
    );
    if (res == null || e.id == null) return;
    try {
      await repo.updateHistory(e.id!,
          watchedAt: res.date, rating: res.rating, comment: res.comment);
    } catch (err) {
      if (context.mounted) _toast(context, context.l10n.errorMessage(friendlyError(err)));
    }
  }

  Future<void> _confirmRemoveCollection(
      BuildContext context, LibraryRepository repo, String id) async {
    final ok = await _confirm(
      context,
      title: context.l10n.detailsRemoveCollectionTitle,
      body: context.l10n.detailsRemoveCollectionBody,
      action: context.l10n.detailsRemoveAction,
    );
    if (!ok) return;
    try {
      await repo.removeFromCollection(id);
    } catch (e) {
      if (context.mounted) _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }

  Future<void> _confirmRemoveHistory(
      BuildContext context, LibraryRepository repo, String id) async {
    final ok = await _confirm(
      context,
      title: context.l10n.detailsDeleteViewingTitle,
      body: context.l10n.detailsDeleteViewingBody,
      action: context.l10n.delete,
    );
    if (!ok) return;
    try {
      await repo.removeFromHistory(id);
    } catch (e) {
      if (context.mounted) _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }
}

// ---------------------------------------------------------------------------
// Section Collection
// ---------------------------------------------------------------------------
class _CollectionSection extends StatelessWidget {
  const _CollectionSection({
    required this.entries,
    required this.isSeries,
    required this.scopeLabel,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
  });

  final List<CollectionView> entries;
  final bool isSeries;
  final String Function(int?) scopeLabel;
  final bool readOnly;
  final VoidCallback onAdd;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(context.l10n.detailsMyCollection,
                        style: theme.textTheme.titleSmall)),
                if (!readOnly)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.add),
                  ),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(context.l10n.detailsNotInCollection,
                    style: theme.textTheme.bodySmall),
              )
            else
              ...entries.map((e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: MediumBadge(medium: e.medium, compact: true),
                    title: Text('${scopeLabel(e.seasonNumber)} · ${e.medium.label}'),
                    subtitle: e.addedAt != null
                        ? Text(context.l10n
                            .detailsAcquiredOn(fmtDateLocalized(context, e.addedAt!)))
                        : null,
                    trailing: readOnly
                        ? null
                        : IconButton(
                            tooltip: context.l10n.detailsRemoveFromCollectionTooltip,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: e.id == null ? null : () => onRemove(e.id!),
                          ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Historique
// ---------------------------------------------------------------------------
class _HistorySection extends ConsumerWidget {
  const _HistorySection({
    required this.entries,
    required this.isSeries,
    required this.scopeLabel,
    required this.readOnly,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final List<HistoryView> entries;
  final bool isSeries;
  final String Function(int?) scopeLabel;
  final bool readOnly;
  final VoidCallback onAdd;
  final void Function(HistoryView e) onEdit;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        context.l10n.detailsViewingHistoryTitle(entries.length),
                        style: theme.textTheme.titleSmall)),
                if (!readOnly)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.detailsViewingButton),
                  ),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(context.l10n.detailsNoViewings,
                    style: theme.textTheme.bodySmall),
              )
            else
              ...entries.map((e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility, size: 20),
                    title: Text(
                      '${context.l10n.detailsWatchedOn(fmtDateLocalized(context, e.watchedAt))}'
                      '${e.seasonNumber != null ? ' · ${scopeLabel(e.seasonNumber)}' : ''}'
                      '${e.episodeNumber != null ? ' · E${e.episodeNumber} ${resolveEpisodeName(ref, tmdbId: e.film.tmdbId, seasonNumber: e.seasonNumber ?? 0, episodeNumber: e.episodeNumber!, stored: e.episodeName)}' : ''}'
                      '${e.rating != null ? ' · ${e.rating!.toStringAsFixed(1)}/10' : ''}',
                    ),
                    subtitle: (e.comment ?? '').isNotEmpty
                        ? Text(e.comment!,
                            style: const TextStyle(fontStyle: FontStyle.italic))
                        : null,
                    onTap: readOnly ? null : () => onEdit(e),
                    trailing: readOnly
                        ? null
                        : IconButton(
                            tooltip: context.l10n.detailsDeleteViewingTooltip,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: e.id == null ? null : () => onRemove(e.id!),
                          ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bouton pense-bête
// ---------------------------------------------------------------------------
class _WishlistButton extends ConsumerWidget {
  const _WishlistButton({required this.film, required this.season});

  final Film film;
  final FilmSeason? season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = '${film.mediaKey}|${season?.seasonNumber}';
    final existing = ref.watch(wishlistByKeyProvider)[key];
    final on = existing != null;
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: Icon(on ? Icons.bookmark : Icons.bookmark_border, size: 18),
        label: Text(on ? l10n.wishlistRemoveTooltip : l10n.wishlistAddTooltip),
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: () async {
          final repo = ref.read(libraryRepositoryProvider);
          try {
            if (on) {
              if (existing.id != null) {
                await repo.removeFromWishlist(existing.id!);
              }
            } else {
              await repo.addToWishlist(film, season: season);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.errorMessage(friendlyError(e)))));
            }
          }
        },
      ),
    );
  }
}
