import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/utils/format.dart';
import '../../data/models/history_entry.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/dark_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/keyboard_scroll.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../collection/collection_filter.dart';
import '../collection/history_sort.dart';
import 'share_service.dart';

/// Largeur au-delà de laquelle le panneau de filtres est affiché en colonne.
const double _kWide = 720;

/// Écran public (sans compte) d'un historique partagé. Lecture seule : le
/// destinataire peut uniquement changer les filtres et le tri. Les données sont
/// chargées en direct via les RPC confinées au token ; l'état de filtre/tri du
/// lien sert d'état initial.
///
/// Entièrement autonome (état local, pas d'override de providers) : ni les
/// modales ni les providers dérivés ne peuvent lire par erreur les données de
/// l'utilisateur connecté à la place de celles du partage.
class SharedHistoryScreen extends ConsumerWidget {
  const SharedHistoryScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(sharedHistoryProvider(token));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: AppBarTitle(l10n.sharedHistoryTitle)),
        body: EmptyState(
          message: e is ShareUnavailable
              ? l10n.sharedUnavailable
              : l10n.errorMessage(friendlyError(e)),
        ),
      ),
      data: (data) => _SharedHistoryBody(data: data),
    );
  }
}

class _SharedHistoryBody extends ConsumerStatefulWidget {
  const _SharedHistoryBody({required this.data});

  final SharedHistoryData data;

  @override
  ConsumerState<_SharedHistoryBody> createState() => _SharedHistoryBodyState();
}

class _SharedHistoryBodyState extends ConsumerState<_SharedHistoryBody> {
  late CollectionFilter _filter = widget.data.filter;
  late HistorySort _sort = widget.data.sort;
  final _titleController = TextEditingController();
  String _titleQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _titleQuery = value.trim().toLowerCase());
    });
  }

  bool get _groupByYear =>
      _sort == HistorySort.watchedDesc || _sort == HistorySort.watchedAsc;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMd(locale);
    final all = widget.data.history;
    final wide = MediaQuery.of(context).size.width >= _kWide;

    final matched = all.where(_filter.matchesHistory).toList();

    // Titre affiché (selon la langue de titre choisie) : filtre texte, tri
    // alphabétique et affichage. resolveTitle fait des ref.watch.
    final titleCache = <String, String>{
      for (final v in matched)
        _keyOf(v): resolveTitle(
          ref,
          tmdbId: v.film.tmdbId,
          mediaType: v.film.mediaType,
          title: v.film.title,
          originalTitle: v.film.originalTitle,
        ),
    };
    String titleOf(HistoryView v) => titleCache[_keyOf(v)] ?? v.film.title;

    final filtered = _titleQuery.isEmpty
        ? matched
        : matched
            .where((v) => titleOf(v).toLowerCase().contains(_titleQuery))
            .toList();
    final sorted = [...filtered]..sort(historyComparator(_sort, titleOf));

    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
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
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          isDense: true,
        ),
      ),
    );

    Widget card(HistoryView v) => _SharedHistoryCard(
          event: v,
          title: titleOf(v),
          dateLabel: dateFmt.format(v.watchedAt.toLocal()),
        );

    const grid = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 160,
      childAspectRatio: 0.52,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
    SliverPadding gridSliver(List<HistoryView> items) => SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          sliver: SliverGrid(
            gridDelegate: grid,
            delegate: SliverChildBuilderDelegate(
              (context, i) => card(items[i]),
              childCount: items.length,
            ),
          ),
        );

    final content = sorted.isEmpty
        ? EmptyState(message: l10n.historyEmpty)
        : Builder(builder: (context) {
            final slivers = <Widget>[];
            if (_groupByYear) {
              int? lastYear;
              var bucket = <HistoryView>[];
              void flush() {
                if (bucket.isNotEmpty) slivers.add(gridSliver(bucket));
                bucket = [];
              }

              for (final v in sorted) {
                final y = v.watchedAt.year;
                if (y != lastYear) {
                  flush();
                  slivers.add(SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text('$y',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ));
                  lastYear = y;
                }
                bucket.add(v);
              }
              flush();
            } else {
              slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
              slivers.add(gridSliver(sorted));
            }
            slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
            return KeyboardScroll(
              builder: (ctrl) =>
                  CustomScrollView(controller: ctrl, slivers: slivers),
            );
          });

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(l10n.sharedHistoryTitle),
        actions: [
          PopupMenuButton<HistorySort>(
            tooltip: l10n.sortTooltip,
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              for (final opt in HistorySort.values)
                CheckedPopupMenuItem(
                  value: opt,
                  checked: opt == _sort,
                  child: Text(historySortLabel(l10n, opt)),
                ),
            ],
          ),
          if (!wide)
            IconButton(
              tooltip: l10n.filterTooltip,
              icon: Badge(
                isLabelVisible: _filter.isActive,
                child: const Icon(Icons.filter_list),
              ),
              onPressed: () => _SharedFilterSheet.show(
                context,
                filter: _filter,
                history: all,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
          const OriginalTitleButton(),
          const LanguageButton(),
          const ThemeToggleButton(),
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
                      Container(
                        width: 300,
                        decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(
                                  color: Theme.of(context).dividerColor)),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _SharedFilterPanel(
                            filter: _filter,
                            history: all,
                            onChanged: (f) => setState(() => _filter = f),
                          ),
                        ),
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

  static String _keyOf(HistoryView v) =>
      v.id ?? '${v.watchedAt.microsecondsSinceEpoch}';
}

/// Panneau de filtres autonome pour la vue partagée : facettes (genre, pays,
/// année, note) calculées directement depuis l'historique partagé, édition via
/// [onChanged] (aucun provider global, donc robuste dans une modale).
class _SharedFilterPanel extends ConsumerWidget {
  const _SharedFilterPanel({
    required this.filter,
    required this.history,
    required this.onChanged,
  });

  final CollectionFilter filter;
  final List<HistoryView> history;
  final ValueChanged<CollectionFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final genresById = ref.watch(genresByIdProvider);
    final films = [for (final v in history) v.film];

    final genreKeys = <int, Set<String>>{};
    final countryKeys = <String, Set<String>>{};
    final yearKeys = <int, Set<String>>{};
    for (final f in films) {
      final k = f.mediaKey;
      for (final g in f.genres) {
        (genreKeys[g] ??= {}).add(k);
      }
      final c = f.originCountry;
      if (c != null && c.isNotEmpty) (countryKeys[c] ??= {}).add(k);
      if (f.releaseYear != null) (yearKeys[f.releaseYear!] ??= {}).add(k);
    }
    final presentGenres = genreKeys.entries.toList()
      ..sort((a, b) =>
          (genresById[a.key] ?? '').compareTo(genresById[b.key] ?? ''));
    final presentCountries = countryKeys.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final presentYears = yearKeys.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    // Facette « note » : notes présentes dans l'historique partagé.
    final ratingKeys = <double, int>{};
    var unrated = 0;
    for (final v in history) {
      if (v.rating != null) {
        ratingKeys[v.rating!] = (ratingKeys[v.rating!] ?? 0) + 1;
      } else {
        unrated++;
      }
    }
    final presentRatings = ratingKeys.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    String ratingLabel(double r) {
      final i = r.round();
      return r == i.toDouble() ? '$i ★' : '${r.toStringAsFixed(1)} ★';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(l10n.filterTitle,
                    style: Theme.of(context).textTheme.titleLarge)),
            if (filter.isActive)
              TextButton(
                onPressed: () => onChanged(const CollectionFilter()),
                child: Text(l10n.filterReset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.filterType),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.filterAll),
              selected: filter.mediaType == null,
              onSelected: (_) => onChanged(filter.copyWith(clearMediaType: true)),
            ),
            ChoiceChip(
              label: Text(l10n.filterFilms),
              selected: filter.mediaType == 'movie',
              onSelected: (_) => onChanged(filter.copyWith(mediaType: 'movie')),
            ),
            ChoiceChip(
              label: Text(l10n.filterSeries),
              selected: filter.mediaType == 'tv',
              onSelected: (_) => onChanged(filter.copyWith(mediaType: 'tv')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: filter.genreId,
          decoration: InputDecoration(labelText: l10n.filterGenre),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
            ...presentGenres.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                      '${genresById[e.key] ?? l10n.filterGenreFallback(e.key)} (${e.value.length})'),
                )),
          ],
          onChanged: (v) => onChanged(v == null
              ? filter.copyWith(clearGenre: true)
              : filter.copyWith(genreId: v)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          isExpanded: true,
          initialValue: filter.country,
          decoration: InputDecoration(labelText: l10n.filterCountry),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
            ...presentCountries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text('${countryLabel(e.key)} (${e.value.length})'),
                )),
          ],
          onChanged: (v) => onChanged(v == null
              ? filter.copyWith(clearCountry: true)
              : filter.copyWith(country: v)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: filter.year,
          decoration: InputDecoration(labelText: l10n.filterYear),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.filterAllFeminine)),
            ...presentYears.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.key} (${e.value.length})'),
                )),
          ],
          onChanged: (v) => onChanged(v == null
              ? filter.copyWith(clearYear: true)
              : filter.copyWith(year: v)),
        ),
        if (presentRatings.isNotEmpty || unrated > 0) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<double?>(
            isExpanded: true,
            initialValue: filter.rating,
            decoration: InputDecoration(labelText: l10n.filterRating),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
              ...presentRatings.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text('${ratingLabel(e.key)}  (${e.value})'),
                  )),
              if (unrated > 0)
                DropdownMenuItem(
                  value: -1,
                  child: Text('${l10n.filterRatingNone}  ($unrated)'),
                ),
            ],
            onChanged: (v) => onChanged(v == null
                ? filter.copyWith(clearRating: true)
                : filter.copyWith(rating: v)),
          ),
        ],
      ],
    );
  }
}

/// Repli modal (écrans étroits) du panneau de filtres partagé.
class _SharedFilterSheet {
  static Future<void> show(
    BuildContext context, {
    required CollectionFilter filter,
    required List<HistoryView> history,
    required ValueChanged<CollectionFilter> onChanged,
  }) {
    // État local à la feuille : chaque changement remonte via onChanged ET
    // rafraîchit la feuille (StatefulBuilder) pour refléter la sélection.
    var current = filter;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SingleChildScrollView(
            child: _SharedFilterPanel(
              filter: current,
              history: history,
              onChanged: (f) {
                setSheet(() => current = f);
                onChanged(f);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedHistoryCard extends StatelessWidget {
  const _SharedHistoryCard({
    required this.event,
    required this.title,
    required this.dateLabel,
  });

  final HistoryView event;
  final String title;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSeason = event.seasonNumber != null;
    final year = event.film.releaseYear;
    return Column(
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
              Positioned(
                top: 6,
                right: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (event.rating != null) ...[
                      DarkBadge(
                          icon: Icons.star,
                          label: event.rating!.toStringAsFixed(1)),
                      const SizedBox(height: 4),
                    ],
                    if (isSeason)
                      DarkBadge(
                        icon: Icons.live_tv,
                        label: 'S${event.seasonNumber}'
                            '${event.episodeNumber != null ? 'E${event.episodeNumber}' : ''}',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: title,
            style: theme.textTheme.bodyMedium,
            children: [
              if (year != null)
                TextSpan(
                  text: '  ($year)',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              if (event.totalMinutes != null)
                TextSpan(
                  text: '  ${fmtDuration(event.totalMinutes!)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          children: [
            Icon(Icons.visibility, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(dateLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          ],
        ),
        if ((event.comment ?? '').isNotEmpty)
          Text(event.comment!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic)),
      ],
    );
  }
}
