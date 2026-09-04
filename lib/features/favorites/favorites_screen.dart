import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../data/repositories/favorite_collections_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/language_button.dart';
import '../../widgets/card_title.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/account_button.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';

/// Liste des personnes favorites (vignettes). Ouvre la fiche acteur au clic.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final sagas = ref.watch(favoriteCollectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.favoritesTitle),
        actions: const [LanguageButton(), ThemeToggleButton(), AccountButton()],
      ),
      body: (favorites.isEmpty && sagas.isEmpty)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.favEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                if (sagas.isNotEmpty) ...[
                  _header(context, context.l10n.favSagasSection),
                  _grid(
                    itemCount: sagas.length,
                    builder: (context, i) => _FavCard(
                      posterPath: sagas[i].posterPath,
                      name: sagas[i].name,
                      onTap: () => openSaga(context, ref,
                          id: sagas[i].collectionId,
                          name: sagas[i].name,
                          posterPath: sagas[i].posterPath),
                    ),
                  ),
                ],
                if (favorites.isNotEmpty) ...[
                  _header(context, context.l10n.favPersonsSection),
                  _grid(
                    itemCount: favorites.length,
                    builder: (context, i) => _FavCard(
                      posterPath: favorites[i].profilePath,
                      name: favorites[i].name,
                      onTap: () => openPerson(context, ref,
                          id: favorites[i].personId,
                          name: favorites[i].name,
                          profilePath: favorites[i].profilePath),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ),
    );
  }

  Widget _header(BuildContext context, String label) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child:
              Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
      );

  Widget _grid({
    required int itemCount,
    required Widget Function(BuildContext, int) builder,
  }) =>
      SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.62,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: itemCount,
          itemBuilder: builder,
        ),
      );
}

/// Vignette générique de favori (personne ou saga).
class _FavCard extends StatelessWidget {
  const _FavCard({
    required this.posterPath,
    required this.name,
    required this.onTap,
  });

  final String? posterPath;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PosterImage(posterPath: posterPath, size: 'w342'),
            ),
          ),
          const SizedBox(height: 6),
          CardTitle(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
