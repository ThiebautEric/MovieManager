import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../data/models/film.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';
import 'collection_filter.dart';
import 'filter_sheet.dart';

/// Écran « Historique » : la grille des visionnages, du plus récent au plus
/// ancien. Un titre vu plusieurs fois (ou plusieurs saisons) = une vignette par
/// visionnage. Donnée totalement indépendante de la collection.
String _fmtDate(DateTime d) =>
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
    final events = ref.read(filteredHistoryProvider);
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    // Le BOM en tête permet à Excel de détecter l'UTF-8 (accents).
    final bom = String.fromCharCode(0xFEFF);
    final b = StringBuffer('${bom}Numero;Titre;Saison;Note;Date\n');
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final saison = e.seasonNumber != null ? 'S${e.seasonNumber}' : '';
      final note = e.rating != null ? e.rating!.toStringAsFixed(1) : '';
      b.writeln('${i + 1};${q(e.film.title)};$saison;$note;${_fmtDate(e.watchedAt)}');
    }
    await FileSaver.instance.saveFile(
      name: 'historique',
      bytes: Uint8List.fromList(utf8.encode(b.toString())),
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historique exporté (historique.csv)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final owned = <String, Set<Medium>>{};
    for (final c in (ref.watch(collectionStreamProvider).value ?? [])) {
      (owned['${c.film.mediaKey}|${c.seasonNumber}'] ??= {}).add(c.medium);
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
          dateLabel: _fmtDate(e.watchedAt),
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
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (_) {
        if (events.isEmpty) {
          return const _EmptyState(
            message:
                'Aucun visionnage à afficher.\nAjoute un film ou une saison à ton historique (ou ajuste les filtres).',
          );
        }
        // Regroupe les visionnages (déjà triés du + récent au + ancien) par
        // mois, avec un en-tête d'année quand l'année change.
        final groups = <_MonthGroup>[];
        for (final e in events) {
          final y = e.watchedAt.year, m = e.watchedAt.month;
          if (groups.isEmpty || groups.last.year != y || groups.last.month != m) {
            groups.add(_MonthGroup(y, m));
          }
          groups.last.items.add(e);
        }
        const grid = SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 0.52,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        );
        // Totaux par année (pour l'en-tête année).
        final yearStats = <int, _Counts>{};
        for (final e in events) {
          final c = yearStats.putIfAbsent(e.watchedAt.year, () => _Counts());
          if (e.film.mediaType == 'movie') {
            c.films++;
            if (inColl(e)) c.filmsInColl++;
          } else {
            c.series++;
            if (inColl(e)) c.seriesInColl++;
          }
        }

        final slivers = <Widget>[];
        int? lastYear;
        for (final g in groups) {
          if (g.year != lastYear) {
            final collapsed = _collapsed.contains(g.year);
            final s = yearStats[g.year]!;
            slivers.add(SliverToBoxAdapter(
              child: _YearHeader(
                year: g.year,
                counts: s,
                collapsed: collapsed,
                onTap: () => setState(() => collapsed
                    ? _collapsed.remove(g.year)
                    : _collapsed.add(g.year)),
              ),
            ));
            lastYear = g.year;
          }
          if (_collapsed.contains(g.year)) continue; // année repliée
          final films = g.items.where((e) => e.film.mediaType == 'movie');
          final series = g.items.where((e) => e.film.mediaType == 'tv');
          slivers.add(SliverToBoxAdapter(
            child: _MonthHeader(
              month: g.month,
              films: films.length,
              filmsInColl: films.where(inColl).length,
              series: series.length,
              seriesInColl: series.where(inColl).length,
            ),
          ));
          slivers.add(SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            sliver: SliverGrid(
              gridDelegate: grid,
              delegate: SliverChildBuilderDelegate(
                (context, i) => card(g.items[i]),
                childCount: g.items.length,
              ),
            ),
          ));
        }
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
        return RefreshIndicator(
          onRefresh: () => ref.read(libraryRepositoryProvider).refresh(),
          child: CustomScrollView(slivers: slivers),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            tooltip: 'Exporter en CSV (provisoire)',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportCsv,
          ),
          if (!wide)
            IconButton(
              tooltip: 'Filtrer',
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

const _moisFr = [
  '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
];

/// Un mois de visionnages (regroupement de l'historique).
class _MonthGroup {
  _MonthGroup(this.year, this.month);
  final int year;
  final int month;
  final List<HistoryView> items = [];
}

/// Compteurs films/séries vus (et combien possédés en collection).
class _Counts {
  int films = 0, filmsInColl = 0, series = 0, seriesInColl = 0;
}

/// Texte « X films vus (dont Y dans la collection) · Z séries vues (dont W…) ».
String _breakdownText(int films, int filmsColl, int series, int seriesColl) {
  final total = films + series;
  final parts = <String>['$total au total'];
  if (films > 0) {
    parts.add('$films film${films > 1 ? 's' : ''} vu${films > 1 ? 's' : ''} '
        '(dont $filmsColl dans la collection)');
  }
  if (series > 0) {
    parts.add('$series série${series > 1 ? 's' : ''} vue${series > 1 ? 's' : ''} '
        '(dont $seriesColl dans la collection)');
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
    final detail = _breakdownText(
        counts.films, counts.filmsInColl, counts.series, counts.seriesInColl);
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
          ],
        ),
      ),
    );
  }
}

/// Séparateur de mois, avec le détail films/séries vus (dont en collection).
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.films,
    required this.filmsInColl,
    required this.series,
    required this.seriesInColl,
  });

  final int month;
  final int films;
  final int filmsInColl;
  final int series;
  final int seriesInColl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = _breakdownText(films, filmsInColl, series, seriesInColl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_moisFr[month],
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
          if (detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(detail,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSeason = event.seasonNumber != null;
    final rating = event.rating;

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
                    child: _badge(Icons.live_tv, 'S${event.seasonNumber}'),
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
          Text.rich(
            TextSpan(
              text: event.film.title,
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
          if (isSeason)
            Text('Saison ${event.seasonNumber}',
                style: theme.textTheme.bodySmall),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
