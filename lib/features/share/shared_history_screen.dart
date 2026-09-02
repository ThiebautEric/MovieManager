import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/utils/format.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/dark_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/keyboard_scroll.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../collection/collection_filter.dart';
import '../collection/filter_sheet.dart';
import '../collection/history_sort.dart';
import 'share_service.dart';

/// Écran public (sans compte) d'un historique partagé. Lecture seule : le
/// destinataire peut uniquement changer les filtres et le tri. Les données sont
/// chargées en direct via les RPC confinées au token ; l'état de filtre/tri du
/// lien sert d'état initial.
class SharedHistoryScreen extends ConsumerWidget {
  const SharedHistoryScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(sharedHistoryProvider(token));
    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: AppBarTitle(l10n.sharedHistoryTitle)),
        body: EmptyState(
          message: e is ShareUnavailable
              ? l10n.sharedUnavailable
              : l10n.errorMessage(friendlyError(e)),
        ),
      ),
      // Le corps réutilise tout le pipeline de filtre existant : on remplace la
      // source de l'historique (et l'état de filtre initial) dans un ProviderScope
      // imbriqué, sans dépendre de l'authentification.
      data: (data) => ProviderScope(
        overrides: [
          historyStreamProvider.overrideWith((ref) => Stream.value(data.history)),
          historyFilterProvider.overrideWith((ref) => data.filter),
        ],
        child: _SharedHistoryBody(sortInitial: data.sort),
      ),
    );
  }
}

class _SharedHistoryBody extends ConsumerStatefulWidget {
  const _SharedHistoryBody({required this.sortInitial});

  final HistorySort sortInitial;

  @override
  ConsumerState<_SharedHistoryBody> createState() => _SharedHistoryBodyState();
}

class _SharedHistoryBodyState extends ConsumerState<_SharedHistoryBody> {
  late HistorySort _sort = widget.sortInitial;
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
    final filter = ref.watch(historyFilterProvider);
    final all = ref.watch(historyStreamProvider).value ?? const <HistoryView>[];
    final films = [for (final v in all) v.film];
    final events = ref.watch(filteredHistoryProvider);
    final wide = MediaQuery.of(context).size.width >= kFilterBreakpoint;

    // Titre affiché (selon la langue de titre choisie) : sert au filtre texte,
    // au tri alphabétique et à l'affichage. resolveTitle fait des ref.watch.
    final titleCache = <String, String>{
      for (final v in events)
        (v.id ?? '${v.watchedAt.microsecondsSinceEpoch}'): resolveTitle(
          ref,
          tmdbId: v.film.tmdbId,
          mediaType: v.film.mediaType,
          title: v.film.title,
          originalTitle: v.film.originalTitle,
        ),
    };
    String keyOf(HistoryView v) =>
        v.id ?? '${v.watchedAt.microsecondsSinceEpoch}';
    String titleOf(HistoryView v) => titleCache[keyOf(v)] ?? v.film.title;

    final filtered = _titleQuery.isEmpty
        ? events
        : events
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
