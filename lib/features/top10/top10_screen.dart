import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../data/models/film.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';

/// Écran « Top 10 » : les titres préférés, classés par note moyenne
/// personnelle, bonifiée par le nombre de visionnages (revoir un titre est un
/// signal d'appréciation). Seuls les titres notés au moins une fois comptent.
class Top10Screen extends ConsumerWidget {
  const Top10Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(historyStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(l10n.top10Title),
        actions: const [
          OriginalTitleButton(),
          LanguageButton(),
          ThemeToggleButton(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorMessage('$e'))),
        data: (events) {
          final films = _rank(events, movies: true);
          final series = _rank(events, movies: false);
          if (films.isEmpty && series.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.top10Empty, textAlign: TextAlign.center),
              ),
            );
          }
          final theme = Theme.of(context);
          Widget header(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                child: Text(text,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
              );
          Widget list(List<_TopEntry> top) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < top.length; i++)
                    _Top10Tile(rank: i + 1, entry: top[i]),
                ],
              );
          final hint = Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              l10n.top10Hint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              // Deux colonnes côte à côte (films / séries) dès que la place le
              // permet ; sinon deux sections empilées.
              final twoColumns = constraints.maxWidth >= 700;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                child: twoColumns
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          hint,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    header(l10n.filterFilms),
                                    list(films),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    header(l10n.filterSeries),
                                    list(series),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          hint,
                          header(l10n.filterFilms),
                          list(films),
                          header(l10n.filterSeries),
                          list(series),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  /// Agrège l'historique par (titre, saison) — une saison de série est une
  /// entrée à part entière, comme dans l'historique — et renvoie les 10
  /// meilleurs scores des films ([movies] vrai) ou des séries.
  static List<_TopEntry> _rank(List<HistoryView> events,
      {required bool movies}) {
    final byKey = <String, _TopEntry>{};
    for (final e in events) {
      if (e.film.isMovie != movies) continue;
      final t = byKey.putIfAbsent(
          '${e.film.mediaKey}|${e.seasonNumber}|${e.episodeNumber}',
          () => _TopEntry(e.film, e.seasonNumber, e.episodeNumber,
              e.episodeName, e.posterPath));
      t.views++;
      final r = e.rating;
      if (r != null) {
        t.ratingSum += r;
        t.ratedViews++;
      }
    }
    final ranked = byKey.values.where((t) => t.ratedViews > 0).toList()
      ..sort((a, b) {
        final s = b.score.compareTo(a.score);
        if (s != 0) return s;
        final v = b.views.compareTo(a.views);
        if (v != 0) return v;
        final t = a.film.title.compareTo(b.film.title);
        if (t != 0) return t;
        final se = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
        if (se != 0) return se;
        return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
      });
    return ranked.take(10).toList();
  }
}

/// Une entrée agrégée (film, saison de série, ou épisode noté
/// individuellement) : nombre de visionnages et somme des notes.
class _TopEntry {
  _TopEntry(this.film, this.seasonNumber, this.episodeNumber,
      this.episodeName, this.posterPath);

  final Film film;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;

  /// Affiche de la saison si connue, sinon celle du titre.
  final String? posterPath;
  int views = 0;
  double ratingSum = 0;
  int ratedViews = 0;

  double get avgRating => ratingSum / ratedViews;

  /// Note moyenne + 0,25 par visionnage supplémentaire (plafonné à +1,5).
  double get score => avgRating + 0.25 * math.min(views - 1, 6);
}

class _Top10Tile extends ConsumerWidget {
  const _Top10Tile({required this.rank, required this.entry});

  final int rank;
  final _TopEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final film = entry.film;
    final title = resolveTitle(
      ref,
      tmdbId: film.tmdbId,
      mediaType: film.mediaType,
      title: film.title,
      originalTitle: film.originalTitle,
    );
    // Les trois premiers ressortent (taille et couleur du rang).
    final podium = rank <= 3;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: (podium
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: podium
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child:
                      PosterImage(posterPath: entry.posterPath, size: 'w185'),
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
                      '${entry.seasonNumber != null ? ' · ${l10n.collSeasonLabel(entry.seasonNumber!)}' : ''}'
                      '${entry.episodeNumber != null ? ' · ${resolveEpisodeName(ref, tmdbId: film.tmdbId, seasonNumber: entry.seasonNumber ?? 0, episodeNumber: entry.episodeNumber!, stored: entry.episodeName)}' : ''}'
                      '${film.releaseYear != null ? ' · ${film.releaseYear}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 3),
                        Text(entry.avgRating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary)),
                        const SizedBox(width: 12),
                        Icon(Icons.visibility,
                            size: 15, color: theme.colorScheme.outline),
                        const SizedBox(width: 3),
                        Text(l10n.detailsViewingCount(entry.views),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
