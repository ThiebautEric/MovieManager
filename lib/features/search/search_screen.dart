import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/prefs/original_titles_controller.dart';
import '../../core/utils/format.dart';
import '../../core/supabase/view_as.dart';
import '../../data/models/film.dart';
import '../../data/repositories/collection_repository.dart';
import '../../tmdb/models/media_summary.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/season_band.dart';
import '../../tmdb/models/person_summary.dart';
import '../../tmdb/models/search_hit.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/card_title.dart';
import '../../widgets/dark_badge.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/account_button.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';
import 'cover_ocr_provider.dart';
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
      if (mounted) ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  Future<void> _runPhotoSearch() async {
    final picker = ImagePicker();
    // Sur le web mobile, ImageSource.camera ajoute capture="environment"
    // → ouvre directement la caméra. Sur natif Android, gallery donne
    // accès aux deux (galerie + appareil photo).
    final source = kIsWeb ? ImageSource.camera : ImageSource.gallery;
    final XFile? file = await picker.pickImage(source: source);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await ref.read(photoSearchProvider.notifier).searchFromBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    ref.listen<PhotoSearchState>(photoSearchProvider, (_, next) {
      if (next is PhotoSearchDone) {
        _controller.text = next.query;
        ref.read(searchQueryProvider.notifier).state = next.query;
        ref.read(photoSearchProvider.notifier).reset();
        setState(() {});
      } else if (next is PhotoSearchError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.photoSearchError)));
        ref.read(photoSearchProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.searchTitle),
        actions: [
          _PhotoSearchButton(onTap: _runPhotoSearch),
          const OriginalTitleButton(),
          const LanguageButton(),
          const ThemeToggleButton(),
          const AccountButton(),
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
    final mediumByKey = ref.watch(ownedMediumByKeyProvider);
    final watchedKeys = ref.watch(watchedKeysProvider);
    final watchedSeasonsByKey = ref.watch(watchedSeasonsByKeyProvider);
    final ratingByKey = ref.watch(ratingByKeyProvider);
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
              watchedSeasons: watchedSeasonsByKey[
                      '${h.media.mediaType}:${h.media.tmdbId}'] ??
                  const {},
              rating: ratingByKey['${h.media.mediaType}:${h.media.tmdbId}'],
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
    this.watchedSeasons = const {},
    this.rating,
  });

  final MediaSummary item;
  final VoidCallback onTap;
  final Medium? medium;
  final bool watched;
  final Set<int> watchedSeasons;
  final double? rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasBand = watchedSeasons.isNotEmpty;
    final tmdbSeasons = ref.watch(
        seasonsTmdbProvider((id: item.tmdbId, type: item.mediaType)));
    final allKnown = tmdbSeasons.isNotEmpty ? tmdbSeasons : watchedSeasons;
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
                if (hasBand)
                  Positioned(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    child: SeasonBand(watched: watchedSeasons, known: allKnown),
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
                            label: rating!.toStringAsFixed(1)),
                        const SizedBox(height: 4),
                      ],
                      if (medium != null) ...[
                        MediumBadge(medium: medium!),
                        const SizedBox(height: 4),
                      ],
                      if (watched && !hasBand)
                        DarkBadge(icon: Icons.visibility),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: _WishlistBadgeButton(item: item),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          CardTitle(
            resolveTitle(
              ref,
              tmdbId: item.tmdbId,
              mediaType: item.mediaType,
              title: item.title,
              originalTitle: item.originalTitle,
              titleIsLocalized: true,
            ),
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

/// Marque-page 1 clic sur la vignette : ajoute/retire l'œuvre entière du
/// pense-bête. Masqué en consultation (lecture seule).
class _WishlistBadgeButton extends ConsumerWidget {
  const _WishlistBadgeButton({required this.item});

  final MediaSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isViewingAsProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final existing =
        ref.watch(wishlistByKeyProvider)['${item.mediaType}:${item.tmdbId}|null'];
    final on = existing != null;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final repo = ref.read(libraryRepositoryProvider);
          try {
            if (on) {
              if (existing.id != null) {
                await repo.removeFromWishlist(existing.id!);
              }
            } else {
              await repo.addToWishlist(Film.fromSummary(item));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.errorMessage(friendlyError(e)))));
            }
          }
        },
        child: Tooltip(
          message: on ? l10n.wishlistRemoveTooltip : l10n.wishlistAddTooltip,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              on ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
              // Jaune « cadre » quand actif : lisible sur l'affiche sombre.
              color: on ? const Color(0xFFF2C40F) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton caméra dans l'AppBar : lance la sélection d'image et déclenche l'OCR.
class _PhotoSearchButton extends ConsumerWidget {
  const _PhotoSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(photoSearchProvider) is PhotoSearchLoading;
    return IconButton(
      tooltip: context.l10n.photoSearchTooltip,
      icon: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.camera_alt_outlined),
      onPressed: loading ? null : onTap,
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
          CardTitle(person.name, style: theme.textTheme.bodyMedium),
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
