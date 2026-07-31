import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/utils/format.dart';
import '../../data/models/film.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/keyboard_scroll.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/season_band.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';
import 'collection_filter.dart';
import 'filter_sheet.dart';

/// Écran « Historique » : la grille des visionnages, du plus récent au plus
/// ancien. Un titre vu plusieurs fois (ou plusieurs saisons) = une vignette par
/// visionnage. Donnée totalement indépendante de la collection.
///
/// Format de date fixe réservé au CSV (dd/MM/yyyy) ; l'affichage à l'écran
/// utilise DateFormat.yMd selon la locale.
String _fmtDateCsv(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  /// Années repliées (masquent leurs mois/vignettes).
  final Set<int> _collapsed = {};

  /// Vrai une fois le repli par défaut appliqué (toutes années sauf la courante).
  bool _initCollapse = false;

  /// Exporte l'historique affiché en CSV (numéro, titre, saison, note, date).
  /// Web : téléchargement navigateur ; Android/iOS : dossier Téléchargements ;
  /// desktop : dossier de téléchargement par défaut.
  Future<void> _exportCsv() async {
    final l10n = context.l10n;
    final events = ref.read(filteredHistoryProvider);
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    // Le BOM en tête permet à Excel de détecter l'UTF-8 (accents).
    final bom = String.fromCharCode(0xFEFF);
    final b = StringBuffer('$bom${l10n.historyCsvHeader}\n');
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final saison = e.seasonNumber != null
          ? 'S${e.seasonNumber}${e.episodeNumber != null ? 'E${e.episodeNumber}' : ''}'
          : '';
      final titre = e.film.title +
          ((e.episodeName?.isNotEmpty ?? false) ? ' (${e.episodeName})' : '');
      final note = e.rating != null ? e.rating!.toStringAsFixed(1) : '';
      b.writeln(
          '${i + 1};${q(titre)};$saison;$note;${_fmtDateCsv(e.watchedAt)}');
    }
    try {
      await FileSaver.instance.saveFile(
        name: 'historique',
        bytes: Uint8List.fromList(utf8.encode(b.toString())),
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.historyExportedSnack)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorMessage(friendlyError(e)))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMd(locale);
    final async = ref.watch(historyStreamProvider);
    final filter = ref.watch(historyFilterProvider);
    final events = ref.watch(filteredHistoryProvider);
    final films = [for (final v in (async.value ?? const <HistoryView>[])) v.film];

    // Repli par défaut (une seule fois) : toutes les années sauf la courante.
    if (!_initCollapse) {
      final all = async.value ?? const <HistoryView>[];
      if (all.isNotEmpty) {
        final years = all.map((e) => e.watchedAt.year).toSet();
        final now = DateTime.now().year;
        final current =
            years.contains(now) ? now : years.reduce((a, b) => a > b ? a : b);
        _collapsed
          ..clear()
          ..addAll(years.where((y) => y != current));
        _initCollapse = true;
      }
    }
    final wide = MediaQuery.of(context).size.width >= kFilterBreakpoint;

    // Supports possédés par (titre, saison) — pour afficher les pastilles de
    // possession sur les vignettes d'historique (collection et historique
    // restent indépendants ; c'est un simple recoupement d'affichage).
    final collectionValue = ref.watch(collectionStreamProvider).value ?? [];
    final owned = <String, Set<Medium>>{};
    for (final c in collectionValue) {
      (owned['${c.film.mediaKey}|${c.seasonNumber}'] ??= {}).add(c.medium);
    }

    // Toutes les saisons connues par œuvre (history complète + collection) pour
    // afficher en gris les saisons non encore vues dans le bandeau de saisons.
    final knownSeasonsByKey = <String, Set<int>>{};
    for (final e in (async.value ?? const <HistoryView>[])) {
      if (e.seasonNumber != null) {
        (knownSeasonsByKey[e.film.mediaKey] ??= {}).add(e.seasonNumber!);
      }
    }
    for (final c in collectionValue) {
      if (c.seasonNumber != null) {
        (knownSeasonsByKey[c.film.mediaKey] ??= {}).add(c.seasonNumber!);
      }
    }
    List<Medium> mediumsFor(HistoryView e) {
      final set = owned['${e.film.mediaKey}|${e.seasonNumber}'];
      if (set == null) return const [];
      return Medium.values.where(set.contains).toList(); // ordre dvd/bluray/digital
    }
    bool inColl(HistoryView e) =>
        owned.containsKey('${e.film.mediaKey}|${e.seasonNumber}');

    Widget card(HistoryView e) => _HistoryCard(
          event: e,
          dateLabel: dateFmt.format(e.watchedAt),
          mediums: mediumsFor(e),
          onTap: () => openMedia(
            context,
            ref,
            type: e.film.mediaType,
            id: e.film.tmdbId,
            title: e.film.title,
            posterPath: e.film.posterPath,
          ),
        );

    final content = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(friendlyError(e)))),
      data: (_) {
        if (events.isEmpty) {
          return EmptyState(message: l10n.historyEmpty);
        }

        // Collecte tous les visionnages de saison par série (events déjà triés
        // du plus récent au plus ancien).
        final seriesGroupsMap = <String, _SeriesGroup>{};
        for (final e in events) {
          if (!e.film.isMovie &&
              e.seasonNumber != null &&
              e.episodeNumber == null) {
            (seriesGroupsMap[e.film.mediaKey] ??= _SeriesGroup(
              film: e.film,
              allSeasons: knownSeasonsByKey[e.film.mediaKey] ?? const {},
            )).views.add(e);
          }
        }

        // Liste ordonnée de vignettes : les saisons d'une même série sont
        // regroupées en un seul _GroupItem positionné à la date du plus récent.
        final placedSeries = <String>{};
        final allItems = <_HistoryItem>[];
        for (final e in events) {
          if (!e.film.isMovie &&
              e.seasonNumber != null &&
              e.episodeNumber == null) {
            final key = e.film.mediaKey;
            if (placedSeries.add(key)) {
              allItems.add(_GroupItem(seriesGroupsMap[key]!));
            }
          } else {
            allItems.add(_SingleItem(e));
          }
        }

        // Regroupe les items par mois.
        final groups = <_MonthGroup>[];
        for (final item in allItems) {
          final y = item.date.year, m = item.date.month;
          if (groups.isEmpty ||
              groups.last.year != y ||
              groups.last.month != m) {
            groups.add(_MonthGroup(y, m));
          }
          groups.last.items.add(item);
        }

        const grid = SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 0.52,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        );

        // Totaux par année (pour l'en-tête année).
        final yearStats = <int, _Counts>{};
        for (final item in allItems) {
          final counts = yearStats.putIfAbsent(item.date.year, () => _Counts());
          if (item is _SingleItem) {
            counts.add(item.view, owned: inColl(item.view));
          } else if (item is _GroupItem) {
            counts.addGroup(item.group,
                owned: item.group.views.any(inColl));
          }
        }

        bool isCollapsed(int year) =>
            !filter.isActive && _collapsed.contains(year);

        final slivers = <Widget>[];
        int? lastYear;
        for (final g in groups) {
          if (g.year != lastYear) {
            final collapsed = isCollapsed(g.year);
            final s = yearStats[g.year]!;
            slivers.add(SliverToBoxAdapter(
              child: _YearHeader(
                year: g.year,
                counts: s,
                collapsed: collapsed,
                onTap: () => setState(() => _collapsed.contains(g.year)
                    ? _collapsed.remove(g.year)
                    : _collapsed.add(g.year)),
              ),
            ));
            lastYear = g.year;
          }
          if (isCollapsed(g.year)) continue; // année repliée
          final mc = _Counts();
          for (final item in g.items) {
            if (item is _SingleItem) {
              mc.add(item.view, owned: inColl(item.view));
            } else if (item is _GroupItem) {
              mc.addGroup(item.group,
                  owned: item.group.views.any(inColl));
            }
          }
          slivers.add(SliverToBoxAdapter(
            child: _MonthHeader(month: g.month, counts: mc),
          ));
          slivers.add(SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            sliver: SliverGrid(
              gridDelegate: grid,
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = g.items[i];
                  if (item is _SingleItem) return card(item.view);
                  if (item is _GroupItem) {
                    final gr = item.group;
                    return _SeriesGroupCard(
                      group: gr,
                      dateLabel: dateFmt.format(gr.watchedAt),
                      onTap: () => openMedia(
                        context,
                        ref,
                        type: gr.film.mediaType,
                        id: gr.film.tmdbId,
                        title: gr.film.title,
                        posterPath: gr.film.posterPath,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                childCount: g.items.length,
              ),
            ),
          ));
        }
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
        return KeyboardScroll(
          builder: (ctrl) => RefreshIndicator(
            onRefresh: () => ref.read(libraryRepositoryProvider).refresh(),
            child: CustomScrollView(controller: ctrl, slivers: slivers),
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(l10n.historyTitle),
        actions: [
          IconButton(
            tooltip: l10n.historyExportTooltip,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: async.hasValue ? _exportCsv : null,
          ),
          if (!wide)
            IconButton(
              tooltip: l10n.filterTooltip,
              icon: Badge(
                isLabelVisible: filter.isActive,
                child: const Icon(Icons.filter_list),
              ),
              onPressed: () => FilterSheet.show(
                context,
                filterProvider: historyFilterProvider,
                films: films,
                showRating: true,
              ),
            ),
          const OriginalTitleButton(),
          const LanguageButton(),
          const ThemeToggleButton(),
        ],
      ),
      body: wide
          ? Row(
              children: [
                Expanded(child: content),
                FilterSidePanel(
                  filterProvider: historyFilterProvider,
                  films: films,
                  showRating: true,
                ),
              ],
            )
          : content,
    );
  }
}

/// Nom du mois selon la locale, première lettre en majuscule.
String _monthName(BuildContext context, int month) {
  final locale = Localizations.localeOf(context).toString();
  final name = DateFormat.MMMM(locale).format(DateTime(2000, month));
  if (name.isEmpty) return name;
  return name[0].toUpperCase() + name.substring(1);
}

/// Groupe de visionnages d'une même série (plusieurs saisons).
/// Affiché comme une seule vignette avec un bandeau de saisons.
class _SeriesGroup {
  _SeriesGroup({required this.film, required this.allSeasons});

  final Film film;

  /// Toutes les saisons connues (history + collection) — pour les pastilles
  /// grises des saisons non encore vues.
  final Set<int> allSeasons;

  /// Visionnages par saison, du plus récent au plus ancien.
  final List<HistoryView> views = [];

  DateTime get watchedAt => views.first.watchedAt;

  Set<int> get watchedSeasons => {
        for (final v in views)
          if (v.seasonNumber != null) v.seasonNumber!,
      };

  double? get avgRating {
    final rs = [for (final v in views) if (v.rating != null) v.rating!];
    return rs.isEmpty ? null : rs.reduce((a, b) => a + b) / rs.length;
  }

  String? get posterPath => views.first.posterPath ?? film.posterPath;
}

sealed class _HistoryItem {
  DateTime get date;
}

final class _SingleItem extends _HistoryItem {
  _SingleItem(this.view);
  final HistoryView view;
  @override
  DateTime get date => view.watchedAt;
}

final class _GroupItem extends _HistoryItem {
  _GroupItem(this.group);
  final _SeriesGroup group;
  @override
  DateTime get date => group.watchedAt;
}

/// Un mois de visionnages (regroupement de l'historique).
class _MonthGroup {
  _MonthGroup(this.year, this.month);
  final int year;
  final int month;
  final List<_HistoryItem> items = [];
}

/// Compteurs films/séries vus (et combien possédés en collection),
/// plus les durées cumulées en minutes.
class _Counts {
  int films = 0, filmsInColl = 0, series = 0, seriesInColl = 0;
  int filmsMin = 0, seriesMin = 0;

  void add(HistoryView e, {required bool owned}) {
    if (e.film.mediaType == 'movie') {
      films++;
      filmsMin += e.totalMinutes ?? 0;
      if (owned) filmsInColl++;
    } else {
      series++;
      seriesMin += e.totalMinutes ?? 0;
      if (owned) seriesInColl++;
    }
  }

  void addGroup(_SeriesGroup g, {required bool owned}) {
    series++;
    for (final v in g.views) {
      seriesMin += v.totalMinutes ?? 0;
    }
    if (owned) seriesInColl++;
  }
}

/// Durée cumulée, exprimée en jours au-delà de 24 h : « 14h30 », « 3j 7h »…
String _fmtCumul(int minutes, AppLocalizations l10n) {
  if (minutes < 24 * 60) return fmtDuration(minutes);
  final d = minutes ~/ (24 * 60);
  final h = (minutes % (24 * 60)) ~/ 60;
  final day = l10n.historyDayAbbrev;
  return h == 0 ? '$d$day' : '$d$day ${h}h';
}

/// Texte « total : X (films : Y · séries : Z) » — vide si aucune durée connue.
String _durationText(_Counts c, AppLocalizations l10n) {
  final total = c.filmsMin + c.seriesMin;
  if (total == 0) return '';
  final parts = <String>[
    if (c.filmsMin > 0) l10n.historyDurationFilms(_fmtCumul(c.filmsMin, l10n)),
    if (c.seriesMin > 0)
      l10n.historyDurationSeries(_fmtCumul(c.seriesMin, l10n)),
  ];
  return l10n.historyDurationLine(_fmtCumul(total, l10n), parts.join(' · '));
}

/// Texte « X films vus (dont Y dans la collection) · Z séries vues (dont W…) ».
String _breakdownText(
    int films, int filmsColl, int series, int seriesColl, AppLocalizations l10n) {
  final total = films + series;
  final parts = <String>[l10n.historyTotalCount(total)];
  if (films > 0) {
    parts.add(l10n.historyFilmsWatched(films, filmsColl));
  }
  if (series > 0) {
    parts.add(l10n.historySeriesWatched(series, seriesColl));
  }
  return parts.join(' · ');
}

/// Séparateur d'année, repliable, avec le détail annuel.
class _YearHeader extends StatelessWidget {
  const _YearHeader({
    required this.year,
    required this.counts,
    required this.collapsed,
    required this.onTap,
  });

  final int year;
  final _Counts counts;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final detail = _breakdownText(counts.films, counts.filmsInColl,
        counts.series, counts.seriesInColl, l10n);
    final durations = _durationText(counts, l10n);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(collapsed ? Icons.expand_more : Icons.expand_less,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('$year',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant)),
              ],
            ),
            if (detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 2),
                child: Text(detail,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            if (durations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 2),
                child: Text(durations,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Séparateur de mois, avec le détail films/séries vus (dont en collection).
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.counts});

  final int month;
  final _Counts counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final detail = _breakdownText(counts.films, counts.filmsInColl,
        counts.series, counts.seriesInColl, l10n);
    final durations = _durationText(counts, l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_monthName(context, month),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          if (detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(detail,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
          if (durations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(durations,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({
    required this.event,
    required this.dateLabel,
    required this.mediums,
    required this.onTap,
  });

  final HistoryView event;
  final String dateLabel;

  /// Supports possédés pour ce titre/saison (pastilles affichées sur l'affiche).
  final List<Medium> mediums;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSeason = event.seasonNumber != null;
    final rating = event.rating;
    final title = resolveTitle(
      ref,
      tmdbId: event.film.tmdbId,
      mediaType: event.film.mediaType,
      title: event.film.title,
      originalTitle: event.film.originalTitle,
    );

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
                    child: PosterImage(posterPath: event.posterPath),
                  ),
                ),
                if (mediums.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final m in mediums)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: MediumBadge(medium: m, compact: true),
                          ),
                      ],
                    ),
                  ),
                if (isSeason)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _badge(
                        Icons.live_tv,
                        'S${event.seasonNumber}'
                        '${event.episodeNumber != null ? 'E${event.episodeNumber}' : ''}'),
                  ),
                if (rating != null)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: _badge(Icons.star, rating.toStringAsFixed(1)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Titre + durée (film, ou cumul de la saison, « ≈ » car estimé).
          // Tooltip : titre intégral quand il est tronqué.
          Tooltip(
            message: title,
            child: Text.rich(
              TextSpan(
                text: title,
                style: theme.textTheme.bodyMedium,
                children: [
                  if (event.totalMinutes != null)
                    TextSpan(
                      text:
                          '  ${event.isExactDuration ? '' : '≈'}${fmtDuration(event.totalMinutes!)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSeason)
            Builder(builder: (context) {
              final label = '${context.l10n.collSeasonLabel(event.seasonNumber!)}'
                  '${event.episodeNumber != null ? ' · ${resolveEpisodeName(ref, tmdbId: event.film.tmdbId, seasonNumber: event.seasonNumber!, episodeNumber: event.episodeNumber!, stored: event.episodeName)}' : ''}';
              // Tooltip : libellé intégral quand il est tronqué.
              return Tooltip(
                message: label,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
              );
            }),
          Row(
            children: [
              Icon(Icons.visibility, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          if ((event.comment ?? '').isNotEmpty)
            Text(
              event.comment!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
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

/// Vignette d'une série avec bandeau de saisons : une seule vignette par série,
/// regroupant tous les visionnages de saisons.
class _SeriesGroupCard extends ConsumerWidget {
  const _SeriesGroupCard({
    required this.group,
    required this.dateLabel,
    required this.onTap,
  });

  final _SeriesGroup group;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final avgRating = group.avgRating;
    final title = resolveTitle(
      ref,
      tmdbId: group.film.tmdbId,
      mediaType: group.film.mediaType,
      title: group.film.title,
      originalTitle: group.film.originalTitle,
    );

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
                    child: PosterImage(posterPath: group.posterPath),
                  ),
                ),
                // Bandeau vertical de saisons à gauche
                Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  child: SeasonBand(
                    watched: group.watchedSeasons,
                    known: group.allSeasons,
                  ),
                ),
                // Note moyenne en bas à droite
                if (avgRating != null)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: _badge(Icons.star, avgRating.toStringAsFixed(1)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Tooltip(
            message: title,
            child: Text(
              title,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Icon(Icons.live_tv,
                  size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
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

