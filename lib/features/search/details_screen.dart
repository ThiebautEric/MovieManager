import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../home/detail_app_bar.dart';
import '../home/selected_media.dart';

/// Fiche détaillée d'un film/série TMDB (infos + collection + historique).
class DetailsScreen extends ConsumerWidget {
  const DetailsScreen({
    super.key,
    required this.mediaType,
    required this.tmdbId,
    this.embedded = false,
  });

  final String mediaType;
  final int tmdbId;

  /// Vrai quand la fiche est affichée dans la zone droite (grand écran).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync =
        ref.watch(mediaDetailsProvider((id: tmdbId, type: mediaType)));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.detailsTitle),
        leading: DetailLeadingButton(embedded: embedded),
        actions: const [OriginalTitleButton()],
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.errorMessage('$e'))),
        data: (d) => _DetailsBody(details: d),
      ),
    );
  }
}

class _DetailsBody extends ConsumerStatefulWidget {
  const _DetailsBody({required this.details});

  final MediaDetails details;

  @override
  ConsumerState<_DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends ConsumerState<_DetailsBody> {
  @override
  void initState() {
    super.initState();
    // Backfill : si ce titre est déjà dans la bibliothèque mais sans métadonnées
    // récentes (pays/casting), on les complète depuis la fiche TMDB fraîche.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(libraryRepositoryProvider)
          .backfillFilm(Film.fromDetails(widget.details));
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isMovie = details.mediaType == 'movie';
    final titleMode = ref.watch(titleDisplayModeProvider);
    final displayTitle = resolveTitle(
      ref,
      tmdbId: details.tmdbId,
      mediaType: details.mediaType,
      title: details.title,
      originalTitle: details.originalTitle,
      titleIsLocalized: true,
    );
    // L'AUTRE titre (original, ou traduit selon le mode), affiché en
    // italique sous le titre principal s'il en diffère.
    final otherTitle = titleMode == TitleDisplayMode.localized
        ? details.originalTitle
        : details.title;
    final showOther = otherTitle.isNotEmpty && otherTitle != displayTitle;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    PosterImage(posterPath: details.posterPath, size: 'w342'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre + durée totale (film, ou cumul des épisodes).
                  Text.rich(
                    TextSpan(
                      text: displayTitle,
                      style: theme.textTheme.titleLarge,
                      children: [
                        if (details.totalRuntime != null)
                          TextSpan(
                            text:
                                '   ${isMovie ? '' : '≈ '}${fmtDuration(details.totalRuntime!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline),
                          ),
                      ],
                    ),
                  ),
                  if (showOther) ...[
                    const SizedBox(height: 2),
                    Text(
                      titleMode != TitleDisplayMode.localized
                          ? l10n.detailsTranslatedTitle(otherTitle)
                          : l10n.detailsOriginalTitle(otherTitle),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${isMovie ? l10n.film : l10n.serie}'
                    '${details.releaseYear != null ? ' · ${details.releaseYear}' : ''}'
                    // Pour une série : nb d'épisodes et durée unitaire (le
                    // cumul est à côté du titre ; pour un film aussi).
                    '${!isMovie && details.numberOfEpisodes != null ? ' · ${l10n.detailsEpisodeCount(details.numberOfEpisodes!)}' : ''}'
                    '${!isMovie && details.runtime != null ? ' · ${l10n.detailsMinutesPerEpisode(details.runtime!)}' : ''}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 18, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('${details.voteAverage.toStringAsFixed(1)} (TMDB)'),
                    ],
                  ),
                  if (details.directors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                            isMovie
                                ? l10n.detailsDirectorLabel
                                : l10n.detailsCreatorLabel,
                            style: theme.textTheme.bodyMedium),
                        for (final d in details.directors)
                          InkWell(
                            onTap: d.id == 0
                                ? null
                                : () => openPerson(
                                      context,
                                      ref,
                                      id: d.id,
                                      name: d.name,
                                      profilePath: d.profilePath,
                                    ),
                            child: Text(
                              d.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: d.id == 0
                                    ? null
                                    : theme.colorScheme.primary,
                                decoration: d.id == 0
                                    ? null
                                    : TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: details.genres
                        .map((g) => Chip(
                              label: Text(g.name),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _LibraryControls(details: details),
        if (details.overview.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.detailsSynopsis, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(details.overview),
        ],
        if (details.trailers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.detailsTrailers, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...details.trailers.map((v) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_fill),
                title: Text(v.name),
                onTap: () => launchUrl(Uri.parse(v.youtubeUrl),
                    mode: LaunchMode.externalApplication),
              )),
        ],
        if (details.cast.isNotEmpty) ...[
          const SizedBox(height: 24),
          _CastSection(cast: details.cast),
        ],
      ],
    );
  }
}

String _fmtDate(BuildContext context, DateTime d) =>
    DateFormat.yMd(Localizations.localeOf(context).toString()).format(d);

/// Casting : grille (Wrap) qui reste dans la largeur de l'écran — jamais de
/// défilement horizontal, inutilisable à la souris sur le web. Repliée à
/// [_maxCollapsed] vignettes + tuile « +N » toujours visible qui déplie la
/// distribution complète (elle peut dépasser la centaine de personnes depuis
/// la levée de la limite de 15).
class _CastSection extends ConsumerStatefulWidget {
  const _CastSection({required this.cast});

  final List<CastMember> cast;

  @override
  ConsumerState<_CastSection> createState() => _CastSectionState();
}

class _CastSectionState extends ConsumerState<_CastSection> {
  static const _maxCollapsed = 12;

  bool _expanded = false;

  Widget _tile(CastMember c) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: c.id == 0
            ? null
            : () => openPerson(
                  context,
                  ref,
                  id: c.id,
                  name: c.name,
                  profilePath: c.profilePath,
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 96,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PosterImage(posterPath: c.profilePath, size: 'w185'),
              ),
            ),
            const SizedBox(height: 4),
            Text(c.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
            if (c.character.isNotEmpty)
              Text(c.character,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  /// Tuile « +N » qui déplie la distribution complète.
  Widget _moreTile(int hidden) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _expanded = true),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('+$hidden',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
            const SizedBox(height: 4),
            Text(context.l10n.detailsShowAll,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cast = widget.cast;
    final overflowing = cast.length > _maxCollapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.l10n.detailsCastTitle(cast.length),
                  style: theme.textTheme.titleMedium),
            ),
            if (_expanded)
              TextButton(
                onPressed: () => setState(() => _expanded = false),
                child: Text(context.l10n.detailsCollapse),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final c in _expanded ? cast : cast.take(_maxCollapsed))
              _tile(c),
            if (overflowing && !_expanded)
              _moreTile(cast.length - _maxCollapsed),
          ],
        ),
      ],
    );
  }
}

/// Deux sections INDÉPENDANTES : la collection (possessions) et l'historique
/// (visionnages). Ajout/suppression de chacune sans effet sur l'autre. Pour les
/// séries, on peut viser l'œuvre entière ou une saison précise.
class _LibraryControls extends ConsumerWidget {
  const _LibraryControls({required this.details});

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
    // Consultation admin : les listes affichées sont celles d'un autre
    // utilisateur, toute modification est masquée.
    final readOnly = ref.watch(isViewingAsProvider);
    final key = '${details.mediaType}:${details.tmdbId}';
    final collection = (ref.watch(collectionStreamProvider).value ?? [])
        .where((c) => c.film.mediaKey == key)
        .toList();
    final history = (ref.watch(historyStreamProvider).value ?? [])
        .where((h) => h.film.mediaKey == key)
        .toList();

    // Films : collection + historique sur l'œuvre entière.
    if (!_isSeries) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

    // Séries : suivi PAR SAISON (la série entière n'est jamais ajoutable).
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
          style:
              theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
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
          [if (meta.isNotEmpty) meta, summary].join('\n'),
          style: theme.textTheme.bodySmall,
        ),
        children: [
          _CollectionSection(
            entries: coll,
            isSeries: true,
            scopeLabel: (n) => _scopeLabel(context, n),
            readOnly: readOnly,
            onAdd: () =>
                _addCollection(context, repo, season: info.seasonNumber),
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
        ],
      ),
    );
  }

  Future<void> _addCollection(BuildContext context, LibraryRepository repo,
      {required int? season}) async {
    final res = await showDialog<_CollChoice>(
      context: context,
      builder: (_) => const _AddCollectionDialog(),
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
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
    }
  }

  Future<void> _addHistory(BuildContext context, LibraryRepository repo,
      {required int? season}) async {
    final res = await showDialog<_HistChoice>(
      context: context,
      builder: (_) => const _AddHistoryDialog(),
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
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
    }
  }

  Future<void> _editHistory(
      BuildContext context, LibraryRepository repo, HistoryView e) async {
    final res = await showDialog<_HistChoice>(
      context: context,
      builder: (_) => _AddHistoryDialog(
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
      if (context.mounted) _toast(context, context.l10n.errorMessage('$err'));
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
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
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
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
    }
  }
}

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
                    title: Text(
                      '${scopeLabel(e.seasonNumber)} · ${e.medium.label}',
                    ),
                    subtitle: e.addedAt != null
                        ? Text(context.l10n
                            .detailsAcquiredOn(_fmtDate(context, e.addedAt!)))
                        : null,
                    trailing: readOnly
                        ? null
                        : IconButton(
                            tooltip:
                                context.l10n.detailsRemoveFromCollectionTooltip,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed:
                                e.id == null ? null : () => onRemove(e.id!),
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
class _HistorySection extends StatelessWidget {
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
                Icon(Icons.history,
                    size: 18, color: theme.colorScheme.primary),
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
                      '${context.l10n.detailsWatchedOn(_fmtDate(context, e.watchedAt))}'
                      '${e.seasonNumber != null ? ' · ${scopeLabel(e.seasonNumber)}' : ''}'
                      '${e.rating != null ? ' · ${e.rating!.toStringAsFixed(1)}/10' : ''}',
                    ),
                    subtitle: (e.comment ?? '').isNotEmpty
                        ? Text(e.comment!,
                            style:
                                const TextStyle(fontStyle: FontStyle.italic))
                        : null,
                    onTap: readOnly ? null : () => onEdit(e),
                    trailing: readOnly
                        ? null
                        : IconButton(
                            tooltip: context.l10n.detailsDeleteViewingTooltip,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed:
                                e.id == null ? null : () => onRemove(e.id!),
                          ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogues d'ajout
// ---------------------------------------------------------------------------
class _CollChoice {
  _CollChoice(this.medium, this.date);
  final Medium medium;
  final DateTime date;
}

class _HistChoice {
  _HistChoice(this.date, this.rating, this.comment);
  final DateTime date;
  final double? rating;
  final String? comment;
}

class _AddCollectionDialog extends StatefulWidget {
  const _AddCollectionDialog();

  @override
  State<_AddCollectionDialog> createState() => _AddCollectionDialogState();
}

class _AddCollectionDialogState extends State<_AddCollectionDialog> {
  Medium _medium = Medium.dvd;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.detailsAddToCollection),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.detailsMediumLabel),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: Medium.values
                  .map((m) => ChoiceChip(
                        label: Text(m.label),
                        avatar: Icon(m.icon, size: 18),
                        selected: _medium == m,
                        onSelected: (_) => setState(() => _medium = m),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _DateRow(
              text: l10n.detailsAcquiredOn(_fmtDate(context, _date)),
              date: _date,
              onPick: (d) => setState(() => _date = d),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _CollChoice(_medium, _date)),
          child: Text(l10n.add),
        ),
      ],
    );
  }
}

class _AddHistoryDialog extends StatefulWidget {
  const _AddHistoryDialog({
    this.initialDate,
    this.initialRating,
    this.initialComment,
    this.title,
  });

  final DateTime? initialDate;
  final double? initialRating;
  final String? initialComment;

  /// Titre du dialogue ; par défaut « Ajouter un visionnage » (localisé).
  final String? title;

  @override
  State<_AddHistoryDialog> createState() => _AddHistoryDialogState();
}

class _AddHistoryDialogState extends State<_AddHistoryDialog> {
  late DateTime _date = widget.initialDate ?? DateTime.now();
  late double _rating = widget.initialRating ?? 0;
  late final TextEditingController _comment =
      TextEditingController(text: widget.initialComment ?? '');

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title ?? l10n.detailsAddViewing),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateRow(
              text: l10n.detailsWatchedOn(_fmtDate(context, _date)),
              date: _date,
              onPick: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.detailsRatingLabel),
                Expanded(
                  child: Slider(
                    value: _rating,
                    min: 0,
                    max: 10,
                    divisions: 20,
                    label: _rating == 0
                        ? l10n.detailsRatingNone
                        : _rating.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    _rating == 0 ? '—' : _rating.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            TextField(
              controller: _comment,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.detailsCommentLabel,
                hintText: l10n.detailsCommentHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _HistChoice(
              _date,
              _rating > 0 ? _rating : null,
              _comment.text.trim().isEmpty ? null : _comment.text.trim(),
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow(
      {required this.text, required this.date, required this.onPick});

  /// Texte complet déjà localisé (ex. « Acquis le 12/07/2026 »).
  final String text;
  final DateTime date;
  final void Function(DateTime) onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text)),
        TextButton(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(1900),
              lastDate: now,
            );
            if (picked != null) onPick(picked);
          },
          child: Text(context.l10n.detailsEditButton),
        ),
      ],
    );
  }
}
