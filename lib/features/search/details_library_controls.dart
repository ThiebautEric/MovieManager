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
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/add_entry_dialogs.dart';
import '../../widgets/dark_badge.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../home/detail_app_bar.dart';
import '../home/selected_media.dart';
import 'details_cast_section.dart';
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

// ---------------------------------------------------------------------------
// Navigation saison / épisode (utilisée depuis les écrans liste ET la série)
// ---------------------------------------------------------------------------

/// Ouvre la fiche appropriée depuis n'importe quelle page :
/// - épisode (episodeNumber non nul) → EpisodeScreen
/// - saison (seasonNumber non nul, episodeNumber nul) → SeasonScreen
/// - film / série sans saison → DetailsScreen via [openMedia]
Future<void> openEntry(
  BuildContext context,
  WidgetRef ref, {
  required int tmdbId,
  required String mediaType,
  required String title,
  String? posterPath,
  int? seasonNumber,
  int? episodeNumber,
  String? episodeName,
}) async {
  if (seasonNumber == null || mediaType != 'tv') {
    openMedia(context, ref,
        type: mediaType, id: tmdbId, title: title, posterPath: posterPath);
    return;
  }
  try {
    final details = await ref
        .read(mediaDetailsProvider((id: tmdbId, type: mediaType)).future);
    if (!context.mounted) return;
    final info = details.seasons.firstWhere(
      (s) => s.seasonNumber == seasonNumber,
      orElse: () => SeasonInfo(
        seasonNumber: seasonNumber,
        name: '',
        episodeCount: 0,
        overview: '',
        posterPath: null,
        airDate: null,
      ),
    );
    if (episodeNumber == null) {
      _pushSeason(context, ref, details: details, info: info);
    } else {
      final episodes = await ref.read(
          seasonEpisodesProvider((id: tmdbId, season: seasonNumber)).future);
      if (!context.mounted) return;
      final episode = episodes.firstWhere(
        (e) => e.episodeNumber == episodeNumber,
        orElse: () => EpisodeInfo(
          episodeNumber: episodeNumber,
          name: episodeName ?? '',
          runtime: null,
          airDate: null,
          stillPath: null,
          overview: '',
        ),
      );
      _pushEpisode(context, ref, details: details, info: info, episode: episode);
    }
  } catch (_) {
    if (context.mounted) {
      openMedia(context, ref,
          type: mediaType, id: tmdbId, title: title, posterPath: posterPath);
    }
  }
}

void _pushSeason(
  BuildContext context,
  WidgetRef ref, {
  required MediaDetails details,
  required SeasonInfo info,
}) {
  if (MediaQuery.of(context).size.width >= kWideBreakpoint) {
    ref.read(detailStackProvider.notifier).state = [
      ...ref.read(detailStackProvider),
      SeasonEntry(details: details, info: info),
    ];
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SeasonScreen(details: details, info: info)),
    );
  }
}

void _pushEpisode(
  BuildContext context,
  WidgetRef ref, {
  required MediaDetails details,
  required SeasonInfo info,
  required EpisodeInfo episode,
}) {
  if (MediaQuery.of(context).size.width >= kWideBreakpoint) {
    ref.read(detailStackProvider.notifier).state = [
      ...ref.read(detailStackProvider),
      EpisodeEntry(details: details, info: info, episode: episode),
    ];
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              EpisodeScreen(details: details, info: info, episode: episode)),
    );
  }
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(context.l10n.detailsSeasonsTitle,
              style: theme.textTheme.titleMedium),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const maxExtent = 160.0;
            const spacing = 10.0;
            final cols = (constraints.maxWidth / maxExtent).ceil().clamp(1, 100);
            final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: 12,
              children: [
                for (final s in details.seasons)
                  _seasonCard(
                    context,
                    ref,
                    repo,
                    s,
                    collBySeason[s.seasonNumber] ?? const [],
                    histBySeason[s.seasonNumber] ?? const [],
                    readOnly: readOnly,
                    width: cardWidth,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _seasonCard(
    BuildContext context,
    WidgetRef ref,
    LibraryRepository repo,
    SeasonInfo info,
    List<CollectionView> coll,
    List<HistoryView> hist, {
    required bool readOnly,
    double width = 160,
  }) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final title = info.name.isNotEmpty
        ? info.name
        : l10n.detailsSeasonNumber(info.seasonNumber);

    final ratedHist = hist.where((h) => h.rating != null).toList();
    String? seasonRating;
    if (ratedHist.isNotEmpty) {
      final avg =
          ratedHist.map((h) => h.rating!).reduce((a, b) => a + b) / ratedHist.length;
      seasonRating = avg.toStringAsFixed(1);
    }

    final runtimeMin = coll.firstOrNull?.season?.runtimeMinutes ??
        hist.firstOrNull?.season?.runtimeMinutes;
    final mediums = coll.map((c) => c.medium).toSet().toList();

    final metaParts = <String>[
      if (info.year != null) '${info.year}',
      if (info.episodeCount > 0) l10n.detailsEpisodeCount(info.episodeCount),
    ];

    final tracked = coll.isNotEmpty || hist.isNotEmpty;
    final statusParts = <String>[
      if (hist.isNotEmpty) l10n.detailsViewingCount(hist.length),
      if (coll.isNotEmpty) l10n.detailsMediaCount(coll.length),
    ];
    final statusText =
        tracked ? statusParts.join(' · ') : l10n.detailsSeasonNotTracked;

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showSeasonDetail(context, ref, info),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          PosterImage(posterPath: info.posterPath, size: 'w185'),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (seasonRating != null) ...[
                          DarkBadge(icon: Icons.star, label: seasonRating),
                          const SizedBox(height: 4),
                        ],
                        for (final m in mediums) ...[
                          MediumBadge(medium: m, compact: true),
                          const SizedBox(height: 3),
                        ],
                        DarkBadge(
                            icon: Icons.live_tv,
                            label: 'S${info.seasonNumber}'),
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
                  if (runtimeMin != null)
                    TextSpan(
                      text: '  ${fmtDuration(runtimeMin)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (metaParts.isNotEmpty)
              Text(
                metaParts.join(' · '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            Text(
              statusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tracked
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeasonDetail(BuildContext context, WidgetRef ref, SeasonInfo info) {
    _pushSeason(context, ref, details: details, info: info);
  }

  /// Mini-affiche + titre de l'œuvre pour l'en-tête des dialogues.
  Widget _dialogHeader(BuildContext context, int? season) => DialogMediaHeader(
        posterPath: details.libraryPosterPath,
        title: details.title,
        subtitle: _scopeLabel(context, season),
      );

  Future<void> _addCollection(BuildContext context, LibraryRepository repo,
      {required int? season}) async {
    final res = await showDialog<CollChoice>(
      context: context,
      builder: (_) => AddCollectionDialog(header: _dialogHeader(context, season)),
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
      builder: (_) => AddHistoryDialog(header: _dialogHeader(context, season)),
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
        header: _dialogHeader(context, e.seasonNumber),
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
// Vignette poster commune aux entrées collection / historique
// ---------------------------------------------------------------------------

/// Petite affiche arrondie (46×69) posée à gauche d'une entrée collection /
/// historique pour donner un repère visuel.
class _EntryThumb extends StatelessWidget {
  const _EntryThumb({required this.posterPath});

  final String? posterPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 69,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: PosterImage(posterPath: posterPath, size: 'w92'),
      ),
    );
  }
}

/// Badge « note » ambre (★ 8.0) réutilisé dans l'historique.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 13, color: Colors.amber),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
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
    // Plus récemment acquis en premier (les dates nulles en fin de liste).
    final items = [...entries]..sort((a, b) {
        final da = a.addedAt, db = b.addedAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
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
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(context.l10n.detailsNotInCollection,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              )
            else
              for (final e in items) _tile(context, e),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, CollectionView e) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final duration = e.totalMinutes;
    final meta = <String>[
      if (e.addedAt != null) l10n.detailsAcquiredOn(fmtDateLocalized(context, e.addedAt!)),
      if (duration != null) fmtDuration(duration),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _EntryThumb(posterPath: e.posterPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(scopeLabel(e.seasonNumber),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                MediumBadge(medium: e.medium),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(meta.join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ],
            ),
          ),
          if (!readOnly)
            IconButton(
              tooltip: l10n.detailsRemoveFromCollectionTooltip,
              icon: const Icon(Icons.close, size: 18),
              onPressed: e.id == null ? null : () => onRemove(e.id!),
            ),
        ],
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
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(context.l10n.detailsNoViewings,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              )
            else
              for (final e in ([...entries]
                    ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt))))
                _tile(context, ref, e),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, HistoryView e) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // Portée : « Saison X · E3 · Titre » (série) ou vide (film).
    final scopeParts = <String>[
      if (e.seasonNumber != null && e.episodeNumber == null)
        scopeLabel(e.seasonNumber),
      if (e.episodeNumber != null)
        'E${e.episodeNumber} ${resolveEpisodeName(ref, tmdbId: e.film.tmdbId, seasonNumber: e.seasonNumber, episodeNumber: e.episodeNumber!, stored: e.episodeName)}'
            .trim(),
    ];
    final duration = e.totalMinutes;
    final meta = <String>[
      if (scopeParts.isNotEmpty) scopeParts.join(' · '),
      if (duration != null) fmtDuration(duration),
    ];
    final comment = (e.comment ?? '').trim();

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: readOnly ? null : () => onEdit(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EntryThumb(posterPath: e.posterPath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.detailsWatchedOn(
                              fmtDateLocalized(context, e.watchedAt)),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (e.rating != null) ...[
                        const SizedBox(width: 8),
                        _RatingBadge(rating: e.rating!),
                      ],
                    ],
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta.join(' · '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          left: BorderSide(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.6),
                              width: 3),
                        ),
                      ),
                      child: Text(comment,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic)),
                    ),
                  ],
                ],
              ),
            ),
            if (!readOnly)
              IconButton(
                tooltip: l10n.detailsDeleteViewingTooltip,
                icon: const Icon(Icons.close, size: 18),
                onPressed: e.id == null ? null : () => onRemove(e.id!),
              ),
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

// ---------------------------------------------------------------------------
// Écran de détail d'une saison
// ---------------------------------------------------------------------------

/// Page dédiée à une saison : synopsis, épisodes en vignettes, sections
/// collection / historique. Accessible depuis la grille des saisons.
class SeasonScreen extends ConsumerWidget {
  const SeasonScreen({
    super.key,
    required this.details,
    required this.info,
    this.embedded = false,
  });

  final MediaDetails details;
  final SeasonInfo info;
  final bool embedded;

  Film get _film => Film.fromDetails(details);
  FilmSeason _season() => FilmSeason.fromInfo(info);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final repo = ref.read(libraryRepositoryProvider);
    final readOnly = ref.watch(isViewingAsProvider);

    final mediaKey = '${details.mediaType}:${details.tmdbId}';
    final coll = (ref.watch(collectionStreamProvider).value ?? [])
        .where((c) =>
            c.film.mediaKey == mediaKey && c.seasonNumber == info.seasonNumber)
        .toList();
    // Entrées de collection niveau saison (sans épisode précis) → section.
    // Entrées épisodiques → dans la fiche épisode.
    final collSection =
        coll.where((c) => c.episodeNumber == null).toList();
    final hist = (ref.watch(historyStreamProvider).value ?? [])
        .where((h) =>
            h.film.mediaKey == mediaKey && h.seasonNumber == info.seasonNumber)
        .toList();
    // Visionnages sans épisode précis (niveau saison) → affichés ici.
    // Visionnages épisodiques → affichés uniquement dans la fiche épisode.
    final histSection =
        hist.where((h) => h.episodeNumber == null).toList();

    final episodesAsync = ref.watch(
        seasonEpisodesProvider((id: details.tmdbId, season: info.seasonNumber)));
    final castAsync = ref.watch(
        seasonCastProvider((id: details.tmdbId, season: info.seasonNumber)));

    final title = info.name.isNotEmpty
        ? info.name
        : l10n.detailsSeasonNumber(info.seasonNumber);

    String scopeLabel(int? n) =>
        l10n.detailsSeasonNumber(n ?? info.seasonNumber);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: DetailLeadingButton(embedded: embedded),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Lien retour vers la fiche série
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => openMedia(context, ref,
                type: details.mediaType,
                id: details.tmdbId,
                title: details.title,
                posterPath: details.libraryPosterPath),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new,
                      size: 12, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      details.title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // En-tête
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TappablePoster(
                posterPath: info.posterPath,
                width: 80,
                height: 120,
                size: 'w185',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    if (info.year != null || info.episodeCount > 0)
                      Text(
                        [
                          if (info.year != null) '${info.year}',
                          if (info.episodeCount > 0)
                            l10n.detailsEpisodeCount(info.episodeCount),
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Synopsis de la saison
          if (info.overview.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.detailsSynopsis, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(info.overview),
          ],

          const SizedBox(height: 16),
          if (!readOnly) ...[
            _WishlistButton(film: _film, season: _season()),
            const SizedBox(height: 12),
          ],
          _CollectionSection(
            entries: collSection,
            isSeries: true,
            scopeLabel: scopeLabel,
            readOnly: readOnly,
            onAdd: () => _addCollection(context, repo),
            onRemove: (id) => _confirmRemoveCollection(context, repo, id),
          ),
          const SizedBox(height: 8),
          _HistorySection(
            entries: histSection,
            isSeries: true,
            scopeLabel: scopeLabel,
            readOnly: readOnly,
            onAdd: () => _addHistory(context, repo),
            onEdit: (e) => _editHistory(context, repo, e),
            onRemove: (id) => _confirmRemoveHistory(context, repo, id),
          ),

          // Grille d'épisodes
          const SizedBox(height: 24),
          Text(l10n.detailsEpisodesTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          episodesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(l10n.errorMessage(friendlyError(e))),
            data: (episodes) => Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                for (final ep in episodes)
                  _EpisodeCard(
                    episode: ep,
                    hist: hist,
                    coll: coll,
                    onTap: () => _openEpisode(context, ref, ep),
                  ),
              ],
            ),
          ),

          // Casting de la saison
          castAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (cast) => cast.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: CastSection(cast: cast),
                  ),
          ),
        ],
      ),
    );
  }

  void _openEpisode(BuildContext context, WidgetRef ref, EpisodeInfo ep) {
    _pushEpisode(context, ref, details: details, info: info, episode: ep);
  }

  /// Mini-affiche de la saison + titre de la série pour l'en-tête des dialogues.
  Widget _dialogHeader(BuildContext context) => DialogMediaHeader(
        posterPath: info.posterPath,
        title: details.title,
        subtitle: info.name.isNotEmpty
            ? info.name
            : context.l10n.detailsSeasonNumber(info.seasonNumber),
      );

  Future<void> _addCollection(
      BuildContext context, LibraryRepository repo) async {
    final res = await showDialog<CollChoice>(
      context: context,
      builder: (_) => AddCollectionDialog(header: _dialogHeader(context)),
    );
    if (res == null) return;
    try {
      await repo.addToCollection(_film,
          season: _season(), medium: res.medium, addedAt: res.date);
    } catch (e) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }

  Future<void> _addHistory(
      BuildContext context, LibraryRepository repo) async {
    final res = await showDialog<HistChoice>(
      context: context,
      builder: (_) => AddHistoryDialog(header: _dialogHeader(context)),
    );
    if (res == null) return;
    try {
      await repo.addToHistory(_film,
          season: _season(),
          watchedAt: res.date,
          rating: res.rating,
          comment: res.comment);
    } catch (e) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(e)));
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
        header: _dialogHeader(context),
      ),
    );
    if (res == null || e.id == null) return;
    try {
      await repo.updateHistory(e.id!,
          watchedAt: res.date, rating: res.rating, comment: res.comment);
    } catch (err) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(err)));
    }
  }

  Future<void> _confirmRemoveCollection(
      BuildContext context, LibraryRepository repo, String id) async {
    final ok = await _confirm(context,
        title: context.l10n.detailsRemoveCollectionTitle,
        body: context.l10n.detailsRemoveCollectionBody,
        action: context.l10n.detailsRemoveAction);
    if (!ok) return;
    try {
      await repo.removeFromCollection(id);
    } catch (e) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }

  Future<void> _confirmRemoveHistory(
      BuildContext context, LibraryRepository repo, String id) async {
    final ok = await _confirm(context,
        title: context.l10n.detailsDeleteViewingTitle,
        body: context.l10n.detailsDeleteViewingBody,
        action: context.l10n.delete);
    if (!ok) return;
    try {
      await repo.removeFromHistory(id);
    } catch (e) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }
}

// ---------------------------------------------------------------------------
// Carte vignette d'épisode
// ---------------------------------------------------------------------------

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.hist,
    required this.coll,
    this.onTap,
  });

  final EpisodeInfo episode;
  final List<HistoryView> hist;
  final List<CollectionView> coll;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ep = episode;

    final watches =
        hist.where((h) => h.episodeNumber == ep.episodeNumber).toList();
    final isWatched = watches.isNotEmpty;

    // Support possédé pour cet épisode (entrée saison entière OU épisode seul)
    final ownedMedium = coll
        .where((c) =>
            c.episodeNumber == null || c.episodeNumber == ep.episodeNumber)
        .map((c) => c.medium)
        .firstOrNull;

    final ratedWatches = watches.where((h) => h.rating != null).toList();
    String? rating;
    if (ratedWatches.isNotEmpty) {
      final avg = ratedWatches.map((h) => h.rating!).reduce((a, b) => a + b) /
          ratedWatches.length;
      rating = avg.toStringAsFixed(1);
    }

    return SizedBox(
      width: 160,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ep.stillPath != null
                          ? PosterImage(posterPath: ep.stillPath, size: 'w300')
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.live_tv,
                                  size: 32, color: theme.colorScheme.outline),
                            ),
                    ),
                  ),
                  if (ownedMedium != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: MediumBadge(medium: ownedMedium, compact: true),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rating != null) ...[
                          DarkBadge(icon: Icons.star, label: rating),
                          const SizedBox(height: 3),
                        ] else if (isWatched) ...[
                          const DarkBadge(icon: Icons.visibility),
                          const SizedBox(height: 3),
                        ],
                        DarkBadge(
                            icon: Icons.live_tv, label: 'E${ep.episodeNumber}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                text: ep.name.isEmpty ? 'E${ep.episodeNumber}' : ep.name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                children: [
                  if (ep.runtime != null)
                    TextSpan(
                      text: '  ${fmtDuration(ep.runtime!)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (ep.airYear != null)
              Text(
                '${ep.airYear}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran de détail d'un épisode
// ---------------------------------------------------------------------------

/// Page dédiée à un épisode : still, métadonnées, synopsis, collection et
/// historique filtrés sur cet épisode.
class EpisodeScreen extends ConsumerWidget {
  const EpisodeScreen({
    super.key,
    required this.details,
    required this.info,
    required this.episode,
    this.embedded = false,
  });

  final MediaDetails details;
  final SeasonInfo info;
  final EpisodeInfo episode;
  final bool embedded;

  Film get _film => Film.fromDetails(details);
  FilmSeason _season() => FilmSeason.fromInfo(info);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final repo = ref.read(libraryRepositoryProvider);
    final readOnly = ref.watch(isViewingAsProvider);

    final mediaKey = '${details.mediaType}:${details.tmdbId}';
    final coll = (ref.watch(collectionStreamProvider).value ?? [])
        .where((c) =>
            c.film.mediaKey == mediaKey &&
            c.seasonNumber == info.seasonNumber &&
            c.episodeNumber == episode.episodeNumber)
        .toList();
    final hist = (ref.watch(historyStreamProvider).value ?? [])
        .where((h) =>
            h.film.mediaKey == mediaKey &&
            h.seasonNumber == info.seasonNumber &&
            h.episodeNumber == episode.episodeNumber)
        .toList();

    final castAsync = ref.watch(episodeCastProvider((
      id: details.tmdbId,
      season: info.seasonNumber,
      episode: episode.episodeNumber,
    )));

    final label = 'S${info.seasonNumber}E${episode.episodeNumber}';
    String scopeLabel(int? _) => label;

    final title = episode.name.isEmpty ? label : episode.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: DetailLeadingButton(embedded: embedded),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Fil d'Ariane + métadonnées + synopsis (AU-DESSUS de l'image)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Série › Saison
                Row(
                  children: [
                    Flexible(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => openMedia(context, ref,
                            type: details.mediaType,
                            id: details.tmdbId,
                            title: details.title,
                            posterPath: details.libraryPosterPath),
                        child: Text(
                          details.title,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right,
                          size: 14, color: theme.colorScheme.outline),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _pushSeason(context, ref,
                          details: details, info: info),
                      child: Text(
                        info.name.isNotEmpty
                            ? info.name
                            : l10n.detailsSeasonNumber(info.seasonNumber),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                    children: [
                      if (episode.airYear != null)
                        TextSpan(text: ' · ${episode.airYear}'),
                      if (episode.runtime != null)
                        TextSpan(text: ' · ${fmtDuration(episode.runtime!)}'),
                    ],
                  ),
                ),
                if (episode.overview.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.detailsSynopsis,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(episode.overview),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Still 16:9 (sous le synopsis) — cliquable pour l'agrandir
          AspectRatio(
            aspectRatio: 16 / 9,
            child: episode.stillPath != null
                ? Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => showImageViewer(context,
                          posterPath: episode.stillPath,
                          heroTag: 'still:${episode.stillPath}'),
                      child: Hero(
                        tag: 'still:${episode.stillPath}',
                        child: PosterImage(
                            posterPath: episode.stillPath, size: 'w780'),
                      ),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.live_tv,
                        size: 64, color: theme.colorScheme.outline),
                  ),
          ),

          // Barre rapide + sections
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!readOnly) ...[
                  _WishlistButton(film: _film, season: _season()),
                  const SizedBox(height: 12),
                ],
                _CollectionSection(
                  entries: coll,
                  isSeries: true,
                  scopeLabel: scopeLabel,
                  readOnly: readOnly,
                  onAdd: () => _addCollection(context, repo),
                  onRemove: (id) => _confirmRemoveCollection(context, repo, id),
                ),
                const SizedBox(height: 8),
                _HistorySection(
                  entries: hist,
                  isSeries: true,
                  scopeLabel: scopeLabel,
                  readOnly: readOnly,
                  onAdd: () => _addHistory(context, repo),
                  onEdit: (e) => _editHistory(context, repo, e),
                  onRemove: (id) => _confirmRemoveHistory(context, repo, id),
                ),
                // Casting de l'épisode
                castAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (cast) => cast.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: CastSection(cast: cast),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCollection(
      BuildContext context, LibraryRepository repo) async {
    final res = await showDialog<CollChoice>(
      context: context,
      builder: (_) =>
          AddCollectionDialog(header: EpisodeHeader(episode: episode)),
    );
    if (res == null) return;
    try {
      await repo.addToCollection(_film,
          season: _season(),
          episodeNumber: episode.episodeNumber,
          medium: res.medium,
          addedAt: res.date);
    } catch (e) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }

  Future<void> _addHistory(
      BuildContext context, LibraryRepository repo) async {
    final res = await showDialog<HistChoice>(
      context: context,
      builder: (_) => AddHistoryDialog(
        title: episode.name.isEmpty ? 'E${episode.episodeNumber}' : episode.name,
        header: EpisodeHeader(episode: episode),
      ),
    );
    if (res == null) return;
    try {
      await repo.addToHistory(
        _film,
        season: _season(),
        episodeNumber: episode.episodeNumber,
        episodeName: episode.name.isEmpty ? null : episode.name,
        episodeRuntime: episode.runtime,
        watchedAt: res.date,
        rating: res.rating,
        comment: res.comment,
      );
    } catch (e) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(e)));
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
        header: EpisodeHeader(episode: episode),
      ),
    );
    if (res == null || e.id == null) return;
    try {
      await repo.updateHistory(e.id!,
          watchedAt: res.date, rating: res.rating, comment: res.comment);
    } catch (err) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(err)));
    }
  }

  Future<void> _confirmRemoveCollection(
      BuildContext context, LibraryRepository repo, String id) async {
    final ok = await _confirm(context,
        title: context.l10n.detailsRemoveCollectionTitle,
        body: context.l10n.detailsRemoveCollectionBody,
        action: context.l10n.detailsRemoveAction);
    if (!ok) return;
    try {
      await repo.removeFromCollection(id);
    } catch (e) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }

  Future<void> _confirmRemoveHistory(
      BuildContext context, LibraryRepository repo, String id) async {
    final ok = await _confirm(context,
        title: context.l10n.detailsDeleteViewingTitle,
        body: context.l10n.detailsDeleteViewingBody,
        action: context.l10n.delete);
    if (!ok) return;
    try {
      await repo.removeFromHistory(id);
    } catch (e) {
      if (context.mounted)
        _toast(context, context.l10n.errorMessage(friendlyError(e)));
    }
  }
}
