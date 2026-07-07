import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/film.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../tmdb/models/person_details.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/owned_format_badge.dart';
import '../../widgets/poster_image.dart';
import '../home/detail_app_bar.dart';
import '../home/selected_media.dart';

/// Fiche détaillée d'une personne (acteur) : infos + filmographie (grille).
class PersonScreen extends ConsumerWidget {
  const PersonScreen({
    super.key,
    required this.personId,
    this.embedded = false,
  });

  final int personId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(personDetailsProvider(personId));
    final isFav = ref.watch(isFavoriteProvider(personId));
    final details = async.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acteur'),
        leading: DetailLeadingButton(embedded: embedded),
        actions: [
          IconButton(
            tooltip: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
            icon: Icon(isFav ? Icons.star : Icons.star_border,
                color: isFav ? Colors.amber : null),
            // Activable seulement une fois les infos (nom/photo) chargées.
            onPressed: details == null
                ? null
                : () => ref.read(favoritesProvider.notifier).toggle(
                      personId: personId,
                      name: details.name,
                      profilePath: details.profilePath,
                    ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (p) => _PersonBody(person: p),
      ),
    );
  }
}

class _PersonBody extends ConsumerWidget {
  const _PersonBody({required this.person});

  final PersonDetails person;

  String _formatDate(String? d) {
    if (d == null || d.length < 10) return d ?? '';
    final p = d.split('-');
    if (p.length != 3) return d;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final collection = ref.watch(collectionStreamProvider).value ?? [];
    final history = ref.watch(historyStreamProvider).value ?? [];
    // Statut par œuvre (clé TMDB) : possédé (support) / vu / note.
    final byKey = <String, _MediaStatus>{};
    for (final c in collection) {
      final s = byKey[c.film.mediaKey] ??= _MediaStatus();
      s.medium ??= c.medium;
    }
    for (final v in history) {
      // L'historique est trié du plus récent au plus ancien → 1re note = la dernière.
      final s = byKey[v.film.mediaKey] ??= _MediaStatus();
      s.watched = true;
      s.rating ??= v.rating;
    }
    final age = person.ageAt(DateTime.now());

    // Regroupe la filmographie par catégorie (le tri par année est déjà appliqué).
    final grouped = <FilmoCategory, List<FilmographyItem>>{};
    for (final f in person.filmography) {
      (grouped[f.category] ??= []).add(f);
    }
    const order = [
      FilmoCategory.film,
      FilmoCategory.serie,
      FilmoCategory.reportage,
      FilmoCategory.autre,
    ];
    const labels = {
      FilmoCategory.film: 'Films',
      FilmoCategory.serie: 'Séries',
      FilmoCategory.reportage: 'Reportages',
      FilmoCategory.autre: 'Autres',
    };
    final sectionSlivers = <Widget>[];

    void addSection(String label, List<FilmographyItem> items) {
      if (items.isEmpty) return;
      sectionSlivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('$label (${items.length})',
              style: theme.textTheme.titleSmall),
        ),
      ));
      sectionSlivers.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            childAspectRatio: 0.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final f = items[i];
            return _FilmographyCard(
              item: f,
              status: byKey['${f.mediaType}:${f.tmdbId}'],
            );
          },
        ),
      ));
    }

    // En tête : les œuvres de cet acteur présentes dans votre collection.
    final inCollection = person.filmography
        .where((f) => byKey.containsKey('${f.mediaType}:${f.tmdbId}'))
        .toList();
    addSection('Dans ta bibliothèque', inCollection);

    // Puis les sections par type.
    for (final cat in order) {
      addSection(labels[cat]!, grouped[cat] ?? const []);
    }
    sectionSlivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PosterImage(
                            posterPath: person.profilePath, size: 'w342'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(person.name, style: theme.textTheme.titleLarge),
                          if (person.knownForDepartment.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(person.knownForDepartment,
                                style: theme.textTheme.bodyMedium),
                          ],
                          if (person.birthday != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Naissance : ${_formatDate(person.birthday)}'
                              '${age != null ? ' (${person.deathday == null ? '$age ans' : '$age ans à son décès'})' : ''}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          if (person.deathday != null) ...[
                            const SizedBox(height: 4),
                            Text('Décès : ${_formatDate(person.deathday)}',
                                style: theme.textTheme.bodyMedium),
                          ],
                          if (person.placeOfBirth != null &&
                              person.placeOfBirth!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(person.placeOfBirth!,
                                style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (person.biography.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Biographie', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _Biography(text: person.biography),
                ],
                const SizedBox(height: 16),
                Text('Filmographie', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
        ...sectionSlivers,
      ],
    );
  }
}

/// Biographie repliable (longue par défaut).
class _Biography extends StatefulWidget {
  const _Biography({required this.text});
  final String text;
  @override
  State<_Biography> createState() => _BiographyState();
}

class _BiographyState extends State<_Biography> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 5,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Voir moins' : 'Voir plus'),
          ),
      ],
    );
  }
}

/// Statut d'une œuvre vis-à-vis de la bibliothèque de l'utilisateur.
class _MediaStatus {
  Medium? medium; // support possédé (null si non possédé)
  bool watched = false;
  double? rating; // note du dernier visionnage

  bool get owned => medium != null;
}

/// Carte d'un film de la filmographie (format grille d'affiches), avec repères
/// possédé / vu / note s'il est dans la bibliothèque.
class _FilmographyCard extends ConsumerWidget {
  const _FilmographyCard({required this.item, required this.status});

  final FilmographyItem item;
  final _MediaStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = status;
    // Met en valeur les films possédés ou vus.
    final highlight = c != null && (c.owned || c.watched);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openMedia(
        context,
        ref,
        type: item.mediaType,
        id: item.tmdbId,
        title: item.title,
        posterPath: item.posterPath,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: highlight
                    ? Border.all(color: scheme.primary, width: 3)
                    : null,
                boxShadow: highlight
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.45),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PosterImage(posterPath: item.posterPath),
                  ),
                ),
                if (c != null && c.medium != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: MediumBadge(medium: c.medium!),
                  ),
                if (c != null && c.watched)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _badge(Icons.visibility, 'Vu'),
                  ),
                if (c?.rating != null)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: _badge(Icons.star, c!.rating!.toStringAsFixed(1)),
                  ),
              ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: highlight ? scheme.primary : null,
                fontWeight: highlight ? FontWeight.bold : null,
              )),
          Text(
            '${item.mediaType == 'movie' ? 'Film' : 'Série'}'
            '${item.releaseYear != null ? ' · ${item.releaseYear}' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          if (item.character.isNotEmpty)
            Text(item.character,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String? label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: label == null ? 4 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          if (label != null) ...[
            const SizedBox(width: 2),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
