import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../data/models/film.dart';
import '../../data/repositories/collection_repository.dart';
import '../../tmdb/models/media_summary.dart';
import '../../tmdb/models/person_summary.dart';
import '../../tmdb/models/search_hit.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';
import 'search_controller.dart';

/// Écran de recherche TMDB (films + séries + personnalités) en grille.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.searchTitle),
        actions: const [
          OriginalTitleButton(),
          LanguageButton(),
          ThemeToggleButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() {});
                _onChanged(v);
              },
            ),
          ),
          Expanded(
            child: results.when(
              data: (items) => _buildResults(context, items, query),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.l10n.searchError('$e')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
      BuildContext context, List<SearchHit> items, String query) {
    if (query.trim().isEmpty) {
      return Center(child: Text(context.l10n.searchStartTyping));
    }
    if (items.isEmpty) {
      return Center(child: Text(context.l10n.searchNoResults));
    }
    // Badges sur les résultats déjà possédés / déjà vus.
    final collection = ref.watch(collectionStreamProvider).value ?? [];
    final history = ref.watch(historyStreamProvider).value ?? [];
    final mediumByKey = <String, Medium>{};
    for (final c in collection) {
      mediumByKey.putIfAbsent(c.film.mediaKey, () => c.medium);
    }
    final watchedKeys = {for (final v in history) v.film.mediaKey};
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final hit = items[i];
        return switch (hit) {
          MediaHit h => _ResultCard(
              item: h.media,
              medium: mediumByKey['${h.media.mediaType}:${h.media.tmdbId}'],
              watched:
                  watchedKeys.contains('${h.media.mediaType}:${h.media.tmdbId}'),
              onTap: () => openMedia(
                context,
                ref,
                type: h.media.mediaType,
                id: h.media.tmdbId,
                title: h.media.title,
                posterPath: h.media.posterPath,
              ),
            ),
          PersonHit h => _PersonCard(
              person: h.person,
              onTap: () => openPerson(
                context,
                ref,
                id: h.person.id,
                name: h.person.name,
                profilePath: h.person.profilePath,
              ),
            ),
        };
      },
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({
    required this.item,
    required this.onTap,
    this.medium,
    this.watched = false,
  });

  final MediaSummary item;
  final VoidCallback onTap;
  final Medium? medium;
  final bool watched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showOriginal = ref.watch(showOriginalTitlesProvider);
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
                    child: PosterImage(posterPath: item.posterPath),
                  ),
                ),
                if (medium != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: MediumBadge(medium: medium!),
                  ),
                if (watched)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.visibility,
                          size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pickTitle(item.title, item.originalTitle, showOriginal),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '${item.mediaType == 'movie' ? context.l10n.film : context.l10n.serie}'
            '${item.releaseYear != null ? ' · ${item.releaseYear}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Carte d'une personnalité dans les résultats de recherche.
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.onTap});

  final PersonSummary person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    child: PosterImage(posterPath: person.profilePath),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black54,
                            blurRadius: 2,
                            offset: Offset(0, 1)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person,
                            size: 12,
                            color: theme.colorScheme.onSecondary),
                        const SizedBox(width: 3),
                        Text(context.l10n.searchPersonBadge,
                            style: TextStyle(
                              color: theme.colorScheme.onSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            person.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            person.knownForDepartment == 'Acting'
                ? context.l10n.searchActor
                : (person.knownForDepartment.isNotEmpty
                    ? person.knownForDepartment
                    : context.l10n.searchPersonality),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
