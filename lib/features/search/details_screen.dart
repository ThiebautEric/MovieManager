import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/supabase/view_as.dart';
import '../../core/utils/format.dart';
import '../../data/models/film.dart';
import '../../data/repositories/collection_repository.dart';
import '../../tmdb/models/media_details.dart';
import '../../tmdb/tmdb_client.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/poster_image.dart';
import '../home/detail_app_bar.dart';
import '../home/selected_media.dart';
import 'details_cast_section.dart';
import 'details_library_controls.dart';

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
        error: (e, _) => Center(child: Text(context.l10n.errorMessage(friendlyError(e)))),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(libraryRepositoryProvider)
          .backfillFilm(Film.fromDetails(widget.details));
      _repairEpisodeNames();
    });
  }

  /// Répare les visionnages d'épisodes au nom générique (stockés avant le
  /// repli en-US) ou sans durée : vrai titre + durée TMDB.
  Future<void> _repairEpisodeNames() async {
    final d = widget.details;
    if (d.mediaType != 'tv') return;
    if (ref.read(isViewingAsProvider)) return;
    try {
      final hist = await ref.read(historyStreamProvider.future);
      if (!mounted) return;
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
    } catch (_) {}
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
                child: PosterImage(posterPath: details.libraryPosterPath, size: 'w342'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: displayTitle,
                      style: theme.textTheme.titleLarge,
                      children: [
                        if (details.releaseYear != null)
                          TextSpan(
                            text: '  (${details.releaseYear})',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline),
                          ),
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
                                : () => openPerson(context, ref,
                                      id: d.id,
                                      name: d.name,
                                      profilePath: d.profilePath,
                                    ),
                            child: Text(
                              d.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: d.id == 0 ? null : theme.colorScheme.primary,
                                decoration: d.id == 0 ? null : TextDecoration.underline,
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
        if (details.overview.isNotEmpty) ...[
          Text(l10n.detailsSynopsis, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(details.overview),
          const SizedBox(height: 24),
        ],
        LibraryControls(details: details),
        if (details.trailers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.detailsTrailers, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...details.trailers.map((v) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_fill),
                title: Text(v.name),
                onTap: () async => launchUrl(Uri.parse(v.youtubeUrl),
                    mode: LaunchMode.externalApplication),
              )),
        ],
        if (details.cast.isNotEmpty) ...[
          const SizedBox(height: 24),
          CastSection(cast: details.cast),
        ],
      ],
    );
  }
}
