import 'dart:async';
import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/utils/format.dart';
import '../../data/models/film.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/account_button.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/keyboard_scroll.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/dark_badge.dart';
import '../../widgets/season_band.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../core/supabase/supabase_providers.dart';
import '../home/selected_media.dart';
import 'collection_filter.dart';
import 'filter_sheet.dart';

final _historyTitleQueryProvider = StateProvider<String>((ref) {
  ref.keepAlive();
  return '';
});

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final Set<int> _collapsed = {};
  bool _initCollapse = false;
  bool _discFilter = false;
  late final TextEditingController _titleController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: ref.read(_historyTitleQueryProvider),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(_historyTitleQueryProvider.notifier).state =
          value.trim().toLowerCase();
    });
  }

  /// Exporte l'historique affiché en CSV (enrichi pour ré-import).
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
      final note = e.rating != null ? e.rating!.toStringAsFixed(1) : '';
      final numSaison = e.seasonNumber?.toString() ?? '';
      final numEpisode = e.episodeNumber?.toString() ?? '';
      b.writeln(
        '${i + 1}'
        ';${e.film.tmdbId}'
        ';${e.film.mediaType}'
        ';${q(e.film.title)}'
        ';${q(e.film.originalTitle ?? '')}'
        ';$numSaison'
        ';$numEpisode'
        ';${q(e.episodeName ?? '')}'
        ';$note'
        ';${fmtDateCsv(e.watchedAt)}'
        ';${q(e.comment ?? '')}',
      );
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
    final isEric =
        ref.watch(currentUserProvider)?.email == 'thiebaut.eric@laposte.net';
    final events = ref.watch(filteredHistoryProvider);
    final titleQuery = ref.watch(_historyTitleQueryProvider);
    final displayedEvents = titleQuery.isEmpty
        ? events
        : events.where((v) {
            return v.film.title.toLowerCase().contains(titleQuery) ||
                (v.film.originalTitle?.toLowerCase().contains(titleQuery) ??
                    false);
          }).toList();
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

    // Supports possédés et saisons connues — calculés une fois via providers
    // partagés (pas de recalcul à chaque rebuild de cet écran).
    final owned = ref.watch(ownedMediumsByKeySeasonProvider);

    // Toutes les saisons vues par série (historique complet, sans filtre).
    final watchedSeasonsByKey = <String, Set<int>>{};
    for (final e in async.value ?? const <HistoryView>[]) {
      if (e.seasonNumber != null) {
        (watchedSeasonsByKey[e.film.mediaKey] ??= {}).add(e.seasonNumber!);
      }
    }

    List<Medium> mediumsFor(HistoryView e) {
      // Priorité : clé par visionnage si dispo, sinon clé (film|saison|épisode).
      final histSet = e.id != null ? owned['hist:${e.id}'] : null;
      final keySet = owned['${e.film.mediaKey}|${e.seasonNumber}|${e.episodeNumber}'];
      final combined = {...?histSet, ...?keySet};
      return Medium.values.where(combined.contains).toList();
    }
    bool inColl(HistoryView e) =>
        (e.id != null && owned.containsKey('hist:${e.id}')) ||
        owned.containsKey('${e.film.mediaKey}|${e.seasonNumber}|${e.episodeNumber}');

    Widget card(HistoryView e) => _HistoryCard(
          event: e,
          dateLabel: dateFmt.format(e.watchedAt),
          mediums: mediumsFor(e),
          watchedSeasons: watchedSeasonsByKey[e.film.mediaKey] ?? const {},
          showBulk: isEric && _discFilter,
          onTap: () => openMedia(
            context,
            ref,
            type: e.film.mediaType,
            id: e.film.tmdbId,
            title: e.film.title,
            posterPath: e.film.posterPath,
          ),
        );

    // Pré-charge les détails TMDB de toutes les séries de l'historique. Démarre
    // les fetches avant la construction des vignettes ; le provider est keepAlive
    // donc il ne sera pas disposé entre les rebuilds.
    {
      final seenIds = <int>{};
      for (final e in (async.value ?? const <HistoryView>[]).take(20)) {
        if (!e.film.isMovie &&
            e.seasonNumber != null &&
            seenIds.add(e.film.tmdbId)) {
          ref.watch(
              mediaDetailsProvider((id: e.film.tmdbId, type: e.film.mediaType)));
        }
      }
    }

    final content = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(friendlyError(e)))),
      data: (_) {
        final shownEvents = _discFilter
            ? displayedEvents.where((e) {
                final m = mediumsFor(e);
                return m.isEmpty;
              }).toList()
            : displayedEvents;

        if (shownEvents.isEmpty) {
          return EmptyState(message: l10n.historyEmpty);
        }

        final allItems = shownEvents.map(_SingleItem.new).toList();

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
          yearStats.putIfAbsent(item.date.year, () => _Counts())
              .add(item.view, owned: inColl(item.view));
        }

        bool isCollapsed(int year) =>
            !_discFilter &&
            titleQuery.isEmpty &&
            !filter.isActive &&
            _collapsed.contains(year);

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
            if (item is _SingleItem) mc.add(item.view, owned: inColl(item.view));
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

    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              onChanged: _onTitleChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.historySearchHint,
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                suffixIcon: titleQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _titleController.clear();
                          _onTitleChanged('');
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                isDense: true,
              ),
            ),
          ),
          if (isEric) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Sans disque',
                  style: TextStyle(fontSize: 12)),
              selected: _discFilter,
              onSelected: (v) => setState(() => _discFilter = v),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
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
          const AccountButton(),
        ],
      ),
      body: wide
          ? Column(
              children: [
                searchBar,
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: content),
                      FilterSidePanel(
                        filterProvider: historyFilterProvider,
                        films: films,
                        showRating: true,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                searchBar,
                Expanded(child: content),
              ],
            ),
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

sealed class _HistoryItem {
  DateTime get date;
}

final class _SingleItem extends _HistoryItem {
  _SingleItem(this.view);
  final HistoryView view;
  @override
  DateTime get date => view.watchedAt;
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
    required this.watchedSeasons,
    required this.showBulk,
    required this.onTap,
  });

  final HistoryView event;
  final String dateLabel;

  /// Supports possédés pour ce titre/saison (pastilles affichées sur l'affiche).
  final List<Medium> mediums;

  /// Toutes les saisons vues pour cette série (depuis l'historique complet).
  final Set<int> watchedSeasons;
  final bool showBulk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSeason = event.seasonNumber != null;
    final isSeasonOnly = isSeason && event.episodeNumber == null;
    // Chargé pour toutes les entrées de saison (saison entière ou épisode
    // individuel) afin d'afficher l'année correcte de la saison.
    final tmdbDetails = isSeason
        ? ref
            .watch(mediaDetailsProvider(
                (id: event.film.tmdbId, type: event.film.mediaType)))
            .value
        : null;
    final tmdbSeasons = isSeasonOnly && tmdbDetails != null
        ? <int>{
            for (final s in tmdbDetails.seasons)
              if (s.seasonNumber > 0) s.seasonNumber
          }
        : const <int>{};
    final seasonYear = isSeason
        ? (tmdbDetails?.seasons
                .where((s) => s.seasonNumber == event.seasonNumber)
                .firstOrNull
                ?.year ??
            event.film.releaseYear)
        : event.film.releaseYear;
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
                if (isSeasonOnly)
                  Positioned(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    child: SeasonBand(
                      watched: watchedSeasons,
                      known: tmdbSeasons,
                      current: event.seasonNumber,
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rating != null) ...[
                        DarkBadge(
                            icon: Icons.star,
                            label: rating.toStringAsFixed(1)),
                        const SizedBox(height: 4),
                      ],
                      if (isSeason) ...[
                        DarkBadge(
                            icon: Icons.live_tv,
                            label: 'S${event.seasonNumber}'
                                '${event.episodeNumber != null ? 'E${event.episodeNumber}' : ''}'),
                        const SizedBox(height: 4),
                      ],
                      for (final m in mediums) ...[
                        MediumBadge(medium: m, compact: true),
                        const SizedBox(height: 3),
                      ],
                    ],
                  ),
                ),
                if (showBulk)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _BulkAddBar(event: event, owned: mediums),
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
                  if (seasonYear != null)
                    TextSpan(
                      text: '  ($seasonYear)',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
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

}

// ---------------------------------------------------------------------------
// Barre de saisie rapide DVD / Blu-ray (visible uniquement pour thiebaut.eric)
// ---------------------------------------------------------------------------

class _BulkAddBar extends ConsumerStatefulWidget {
  const _BulkAddBar({required this.event, required this.owned});
  final HistoryView event;
  final List<Medium> owned;

  @override
  ConsumerState<_BulkAddBar> createState() => _BulkAddBarState();
}

class _BulkAddBarState extends ConsumerState<_BulkAddBar> {
  final _loading = <Medium>{};

  Future<void> _add(Medium m) async {
    if (_loading.contains(m)) return;
    setState(() => _loading.add(m));
    try {
      await ref.read(libraryRepositoryProvider).addToCollection(
            widget.event.film,
            season: widget.event.season,
            episodeNumber: widget.event.episodeNumber,
            historyId: widget.event.id,
            medium: m,
            addedAt: DateTime.now(),
          );
    } finally {
      if (mounted) setState(() => _loading.remove(m));
    }
  }

  Widget _btn(Medium m, String label) {
    final loading = _loading.contains(m);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: loading ? null : () => _add(m),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.owned.isNotEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: Row(
          children: [
            _btn(Medium.dvd, 'DVD'),
            Container(width: 1, height: 30, color: Colors.white24),
            _btn(Medium.bluray, 'BD'),
            Container(width: 1, height: 30, color: Colors.white24),
            _btn(Medium.digital, 'DIGITAL'),
          ],
        ),
      ),
    );
  }
}


