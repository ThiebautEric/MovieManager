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
import '../../tmdb/models/season_episodes.dart';
import '../../tmdb/tmdb_client.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/add_entry_dialogs.dart';
import '../../widgets/app_bar_title.dart';
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
        title: AppBarTitle(context.l10n.detailsTitle),
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
      _repairEpisodeNames();
    });
  }

  /// Répare les visionnages d'épisodes au nom générique (« Épisode N »,
  /// stockés avant le repli en-US) ou sans durée : vrai titre + durée TMDB.
  Future<void> _repairEpisodeNames() async {
    final d = widget.details;
    if (d.mediaType != 'tv') return;
    if (ref.read(isViewingAsProvider)) return;
    try {
      final hist = await ref.read(historyStreamProvider.future);
      final key = '${d.mediaType}:${d.tmdbId}';
      final broken = [
        for (final h in hist)
          if (h.film.mediaKey == key &&
              h.episodeNumber != null &&
              h.id != null &&
              TmdbClient.isGenericEpisodeName(
                  h.episodeName ?? '', h.episodeNumber!))
            h,
      ];
      if (broken.isEmpty) return;
      final client = ref.read(tmdbClientProvider);
      final repo = ref.read(libraryRepositoryProvider);
      final seasons = {for (final h in broken) h.seasonNumber}.whereType<int>();
      for (final sn in seasons) {
        final byN = {
          for (final e in await client.seasonEpisodes(d.tmdbId, sn))
            e.episodeNumber: e,
        };
        for (final h in broken.where((x) => x.seasonNumber == sn)) {
          final e = byN[h.episodeNumber];
          if (e == null || e.name.isEmpty) continue;
          await repo.updateHistoryEpisodeMeta(h.id!,
              episodeName: e.name, episodeRuntime: e.runtime);
        }
      }
    } catch (_) {
      // Hors ligne / erreur passagère : on réessaiera à la prochaine ouverture.
    }
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
                child: PosterImage(
                    posterPath: details.libraryPosterPath, size: 'w342'),
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
          // Notation par épisode : un visionnage propre à un épisode précis
          // (utile pour les saisons « Specials » composées de téléfilms).
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

  /// Choisit un épisode de la saison (liste TMDB) puis ouvre le dialogue de
  /// visionnage habituel ; l'entrée créée porte le numéro, le nom et la durée
  /// de l'épisode.
  Future<void> _rateEpisode(BuildContext context, LibraryRepository repo,
      SeasonInfo info, List<HistoryView> hist) async {
    final ep = await showDialog<EpisodeInfo>(
      context: context,
      builder: (_) => _EpisodePickerDialog(
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
        header: _EpisodeHeader(episode: ep),
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
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
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
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
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
      if (context.mounted) _toast(context, context.l10n.errorMessage('$e'));
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
                      '${e.episodeNumber != null ? ' · E${e.episodeNumber} ${resolveEpisodeName(ref, tmdbId: e.film.tmdbId, seasonNumber: e.seasonNumber ?? 0, episodeNumber: e.episodeNumber!, stored: e.episodeName)}' : ''}'
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


/// Bouton marque-page : ajoute/retire cette portée (film entier ou saison)
/// du pense-bête. L'état est lu en direct depuis le flux wishlist.
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
                  SnackBar(content: Text(l10n.errorMessage('$e'))));
            }
          }
        },
      ),
    );
  }
}

/// Dialogue de choix d'un épisode (liste TMDB de la saison), avec un œil sur
/// les épisodes déjà présents dans l'historique.
class _EpisodePickerDialog extends ConsumerWidget {
  const _EpisodePickerDialog({
    required this.tmdbId,
    required this.seasonNumber,
    required this.watched,
  });

  final int tmdbId;
  final int seasonNumber;
  final Set<int> watched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async =
        ref.watch(seasonEpisodesProvider((id: tmdbId, season: seasonNumber)));
    return AlertDialog(
      title: Text(l10n.detailsRateEpisode),
      content: SizedBox(
        width: 440,
        height: 440,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.errorMessage('$e'))),
          data: (eps) {
            if (eps.isEmpty) {
              return Center(child: Text(l10n.searchNoResults));
            }
            return ListView.builder(
              itemCount: eps.length,
              itemBuilder: (context, i) {
                final ep = eps[i];
                final meta = [
                  if (ep.runtime != null) fmtDuration(ep.runtime!),
                  if (ep.airYear != null) '${ep.airYear}',
                ].join(' · ');
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 76,
                      height: 43,
                      child: PosterImage(
                          posterPath: ep.stillPath, size: 'w185'),
                    ),
                  ),
                  title: Text(
                      'E${ep.episodeNumber}'
                      '${ep.name.isEmpty ? '' : ' · ${ep.name}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  subtitle: meta.isEmpty ? null : Text(meta),
                  trailing: watched.contains(ep.episodeNumber)
                      ? Icon(Icons.visibility,
                          size: 18, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(context, ep),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel)),
      ],
    );
  }
}

/// En-tête du dialogue de notation d'un épisode : vignette (still TMDB),
/// numéro, durée et année.
class _EpisodeHeader extends StatelessWidget {
  const _EpisodeHeader({required this.episode});

  final EpisodeInfo episode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      'E${episode.episodeNumber}',
      if (episode.runtime != null) fmtDuration(episode.runtime!),
      if (episode.airYear != null) '${episode.airYear}',
    ].join(' · ');
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 120,
            height: 68,
            child: PosterImage(posterPath: episode.stillPath, size: 'w300'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (episode.name.isNotEmpty)
                Text(episode.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(meta,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ],
    );
  }
}
