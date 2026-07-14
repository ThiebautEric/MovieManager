import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../widgets/language_button.dart';
import '../../widgets/card_title.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/theme_toggle_button.dart';
import '../home/selected_media.dart';

/// Liste des personnes favorites (vignettes). Ouvre la fiche acteur au clic.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.favoritesTitle),
        actions: const [LanguageButton(), ThemeToggleButton()],
      ),
      body: favorites.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.favEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, i) {
                final p = favorites[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => openPerson(
                    context,
                    ref,
                    id: p.personId,
                    name: p.name,
                    profilePath: p.profilePath,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: PosterImage(
                              posterPath: p.profilePath, size: 'w342'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      CardTitle(
                        p.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
