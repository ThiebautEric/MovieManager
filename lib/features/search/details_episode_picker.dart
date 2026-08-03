import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/format.dart';
import '../../tmdb/models/season_episodes.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/poster_image.dart';

/// Dialogue de choix d'un épisode (liste TMDB de la saison), avec un œil sur
/// les épisodes déjà présents dans l'historique.
class EpisodePickerDialog extends ConsumerWidget {
  const EpisodePickerDialog({
    super.key,
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
          error: (e, _) => Center(child: Text(l10n.errorMessage(friendlyError(e)))),
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
                      child: PosterImage(posterPath: ep.stillPath, size: 'w185'),
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

/// En-tête du dialogue de notation d'un épisode : vignette, numéro, durée et année.
class EpisodeHeader extends StatelessWidget {
  const EpisodeHeader({super.key, required this.episode});

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
