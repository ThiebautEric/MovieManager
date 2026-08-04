import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../data/models/film.dart';
import '../../data/repositories/collection_repository.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/language_button.dart';
import '../../widgets/account_button.dart';
import '../../widgets/theme_toggle_button.dart';

/// Tableau de bord : compteurs + graphiques sur la collection et l'historique.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collAsync = ref.watch(collectionStreamProvider);
    final histAsync = ref.watch(historyStreamProvider);

    if (collAsync.isLoading || histAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: AppBarTitle(context.l10n.statsTitle),
          actions: const [LanguageButton(), ThemeToggleButton(), AccountButton()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final collection = collAsync.value ?? [];
    final history = histAsync.value ?? [];
    final genresById = ref.watch(genresByIdProvider);

    // Films distincts connus (union collection + historique), par clé TMDB.
    final films = <String, Film>{
      for (final v in history) v.film.mediaKey: v.film,
      for (final c in collection) c.film.mediaKey: c.film,
    };
    final watchedKeys = {for (final v in history) v.film.mediaKey};
    final ownedKeys = {for (final c in collection) c.film.mediaKey};
    // Une note par titre (la plus récente — history est triée par id asc).
    final ratingByFilm = <String, double>{};
    for (final v in history) {
      if (v.rating != null) ratingByFilm[v.film.mediaKey] = v.rating!;
    }
    final ratings = ratingByFilm.values.toList();

    final total = films.length;
    final watched = watchedKeys.length;
    final owned = ownedKeys.length;
    final avg = ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;

    if (total == 0) {
      return Scaffold(
        appBar: AppBar(
          title: AppBarTitle(context.l10n.statsTitle),
          actions: const [LanguageButton(), ThemeToggleButton(), AccountButton()],
        ),
        body: Center(child: Text(context.l10n.statsEmpty)),
      );
    }

    final filmList = films.values.toList();
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        actions: const [LanguageButton(), ThemeToggleButton(), AccountButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryGrid(
            total: total,
            watched: watched,
            owned: owned,
            views: history.length,
            avg: avg,
          ),
          const SizedBox(height: 24),
          Text(l10n.statsWatchedUnwatched,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _WatchedPie(watched: watched, total: total),
          const SizedBox(height: 24),
          Text(l10n.statsTopGenres,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _GenreBars(films: filmList, genresById: genresById),
          const SizedBox(height: 24),
          Text(l10n.statsTopDecades, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _YearPie(films: filmList, noDataLabel: l10n.statsNoYears),
          const SizedBox(height: 24),
          Text(l10n.statsTopCountries, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _CountryPie(
            films: filmList,
            otherLabel: l10n.statsOther,
            noDataLabel: l10n.statsNoCountries,
          ),
          const SizedBox(height: 24),
          Text(l10n.statsTopRatings, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ratings.isEmpty
              ? Text(l10n.statsNoRatings)
              : _RatingPie(ratings: ratings),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.total,
    required this.watched,
    required this.owned,
    required this.views,
    required this.avg,
  });

  final int total;
  final int watched;
  final int owned;
  final int views;
  final double? avg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cards = [
      (l10n.statsCardTitles, '$total', Icons.movie),
      (l10n.statsCardWatched, '$watched', Icons.visibility),
      (l10n.statsCardViews, '$views', Icons.history),
      (l10n.statsCardOwned, '$owned', Icons.inventory_2),
      (
        l10n.statsCardAvgRating,
        avg == null ? '—' : avg!.toStringAsFixed(1),
        Icons.star
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map((c) => SizedBox(
                width: 150,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(c.$3,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 8),
                        Text(c.$2,
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(c.$1,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _WatchedPie extends StatelessWidget {
  const _WatchedPie({required this.watched, required this.total});

  final int watched;
  final int total;

  @override
  Widget build(BuildContext context) {
    final unwatched = total - watched;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 260,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 38,
                sections: [
                  PieChartSectionData(
                    value: watched.toDouble(),
                    title: '$watched',
                    color: scheme.primary,
                    radius: 72,
                    titleStyle: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  PieChartSectionData(
                    value: unwatched.toDouble(),
                    title: '$unwatched',
                    color: scheme.secondaryContainer,
                    radius: 72,
                    titleStyle: TextStyle(
                        color: scheme.onSecondaryContainer, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendItem(
                      color: scheme.primary,
                      label: context.l10n.statsLegendWatched(watched)),
                  const SizedBox(height: 10),
                  _LegendItem(
                      color: scheme.secondaryContainer,
                      label: context.l10n.statsLegendUnwatched(unwatched)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _GenreBars extends StatelessWidget {
  const _GenreBars({required this.films, required this.genresById});

  final List<Film> films;
  final Map<int, String> genresById;

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    for (final f in films) {
      for (final g in f.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(6).toList();
    if (shown.isEmpty) {
      return Text(context.l10n.statsNoGenres);
    }
    final maxCount = shown.first.value.toDouble();
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount + 1,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= shown.length) {
                    return const SizedBox.shrink();
                  }
                  final name = genresById[shown[idx].key] ?? '?';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      name.length > 8 ? '${name.substring(0, 7)}…' : name,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < shown.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: shown[i].value.toDouble(),
                  color: scheme.primary,
                  width: 18,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

// Palette partagée pour les camemberts multi-tranches.
const _kPalette = [
  Color(0xFF4E79A7),
  Color(0xFFF28E2B),
  Color(0xFFE15759),
  Color(0xFF76B7B2),
  Color(0xFF59A14F),
  Color(0xFFEDC948),
  Color(0xFFB07AA1),
  Color(0xFFFF9DA7),
  Color(0xFF9C755F),
  Color(0xFFBAB0AC),
];

/// Camembert générique : liste de (label, count), pie à gauche + légende à droite.
class _SlicePie extends StatelessWidget {
  const _SlicePie({required this.data});

  final List<(String, int)> data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 38,
                sections: [
                  for (var i = 0; i < data.length; i++)
                    PieChartSectionData(
                      value: data[i].$2.toDouble(),
                      title: '',
                      color: _kPalette[i % _kPalette.length],
                      radius: 72,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < data.length; i++) ...[
                    if (i > 0) const SizedBox(height: 5),
                    _LegendItem(
                      color: _kPalette[i % _kPalette.length],
                      label: '${data[i].$1}  (${data[i].$2})',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Camembert par décennie de sortie (films + séries).
class _YearPie extends StatelessWidget {
  const _YearPie({required this.films, required this.noDataLabel});

  final List<Film> films;
  final String noDataLabel;

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    for (final f in films) {
      if (f.releaseYear != null) {
        final decade = (f.releaseYear! ~/ 10) * 10;
        counts[decade] = (counts[decade] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return Text(noDataLabel);
    final data = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return _SlicePie(
      data: data.map((e) => ('${e.key}s', e.value)).toList(),
    );
  }
}

/// Camembert par pays d'origine (films + séries) — top 7 + "Autres".
class _CountryPie extends StatelessWidget {
  const _CountryPie({
    required this.films,
    required this.otherLabel,
    required this.noDataLabel,
  });

  final List<Film> films;
  final String otherLabel;
  final String noDataLabel;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final f in films) {
      if (f.originCountry != null) {
        final c = f.originCountry!;
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return Text(noDataLabel);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const maxTop = 7;
    final top = sorted.take(maxTop).toList();
    final others =
        sorted.skip(maxTop).fold<int>(0, (s, e) => s + e.value);
    final data = <(String, int)>[
      ...top.map((e) => (e.key, e.value)),
      if (others > 0) (otherLabel, others),
    ];
    return _SlicePie(data: data);
  }
}

/// Camembert de la répartition des notes (1–10, tous visionnages notés).
class _RatingPie extends StatelessWidget {
  const _RatingPie({required this.ratings});

  final List<double> ratings;

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    for (final r in ratings) {
      final key = r.round().clamp(1, 10);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final data = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return _SlicePie(
      data: data.map((e) => ('${e.key}★', e.value)).toList(),
    );
  }
}
