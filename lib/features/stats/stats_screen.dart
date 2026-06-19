import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/collection_item.dart';
import '../../data/repositories/collection_repository.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/theme_toggle_button.dart';

/// Tableau de bord : compteurs + graphiques sur la collection.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(collectionStreamProvider).value ?? [];
    final genresById = ref.watch(genresByIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: const [ThemeToggleButton()],
      ),
      body: items.isEmpty
          ? const Center(child: Text('Aucune donnée à afficher.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryGrid(items: items),
                const SizedBox(height: 24),
                Text('Vus / non vus',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(height: 200, child: _WatchedPie(items: items)),
                const SizedBox(height: 24),
                Text('Top genres',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _GenreBars(items: items, genresById: genresById),
              ],
            ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<CollectionItem> items;

  @override
  Widget build(BuildContext context) {
    final watched = items.where((i) => i.watched).length;
    final owned = items.where((i) => i.owned).length;
    final rated = items.where((i) => i.userRating != null).toList();
    final avg = rated.isEmpty
        ? null
        : rated.map((i) => i.userRating!).reduce((a, b) => a + b) /
            rated.length;

    final cards = [
      ('Total', '${items.length}', Icons.movie),
      ('Vus', '$watched', Icons.visibility),
      ('Non vus', '${items.length - watched}', Icons.visibility_off),
      ('Possédés', '$owned', Icons.inventory_2),
      ('Note moy.', avg == null ? '—' : avg.toStringAsFixed(1), Icons.star),
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
  const _WatchedPie({required this.items});

  final List<CollectionItem> items;

  @override
  Widget build(BuildContext context) {
    final watched = items.where((i) => i.watched).length;
    final unwatched = items.length - watched;
    final scheme = Theme.of(context).colorScheme;

    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  value: watched.toDouble(),
                  title: '$watched',
                  color: scheme.primary,
                  radius: 50,
                  titleStyle: TextStyle(
                      color: scheme.onPrimary, fontWeight: FontWeight.bold),
                ),
                PieChartSectionData(
                  value: unwatched.toDouble(),
                  title: '$unwatched',
                  color: scheme.secondaryContainer,
                  radius: 50,
                  titleStyle:
                      TextStyle(color: scheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Legend(color: scheme.primary, label: 'Vus ($watched)'),
            const SizedBox(height: 8),
            _Legend(
                color: scheme.secondaryContainer,
                label: 'Non vus ($unwatched)'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _GenreBars extends StatelessWidget {
  const _GenreBars({required this.items, required this.genresById});

  final List<CollectionItem> items;
  final Map<int, String> genresById;

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    for (final i in items) {
      for (final g in i.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(6).toList();
    if (shown.isEmpty) {
      return const Text('Pas de genres renseignés.');
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
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
