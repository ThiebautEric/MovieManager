import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/collection_item.dart';
import '../../data/repositories/collection_repository.dart';
import '../../tmdb/models/media_details.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/poster_image.dart';
import '../home/detail_app_bar.dart';
import '../home/selected_media.dart';

/// Fiche détaillée d'un film/série TMDB (infos + contrôles de collection).
class DetailsScreen extends ConsumerWidget {
  const DetailsScreen({
    super.key,
    required this.mediaType,
    required this.tmdbId,
    this.embedded = false,
  });

  final String mediaType;
  final int tmdbId;

  /// Vrai quand la fiche est affichée dans la zone droite (grand écran) plutôt
  /// que poussée en plein écran : la fermeture vide alors la sélection.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync =
        ref.watch(mediaDetailsProvider((id: tmdbId, type: mediaType)));
    final collection = ref.watch(collectionStreamProvider).value ?? [];
    final existing = collection
        .where((e) => e.tmdbId == tmdbId && e.mediaType == mediaType)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails'),
        leading: DetailLeadingButton(embedded: embedded),
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (d) => _DetailsBody(details: d, existing: existing),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({required this.details, required this.existing});

  final MediaDetails details;
  final CollectionItem? existing;

  Future<void> _addToCollection(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(collectionRepositoryProvider)
          .upsert(CollectionItem.fromDetails(details));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajouté à votre collection.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMovie = details.mediaType == 'movie';
    final showOriginal = details.originalTitle.isNotEmpty &&
        details.originalTitle != details.title;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PosterImage(posterPath: details.posterPath, size: 'w342'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(details.title, style: theme.textTheme.titleLarge),
                  if (showOriginal) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Titre original : ${details.originalTitle}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${isMovie ? 'Film' : 'Série'}'
                    '${details.releaseYear != null ? ' · ${details.releaseYear}' : ''}'
                    '${details.runtime != null ? ' · ${details.runtime} min' : ''}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 18, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('${details.voteAverage.toStringAsFixed(1)} (TMDB)'),
                    ],
                  ),
                  if (details.directors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${isMovie ? 'Réalisation' : 'Création'} : '
                      '${details.directors.join(', ')}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: details.genres
                        .map((g) => Chip(
                              label: Text(g.name),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Contrôles de collection : édition auto-sauvegardée si déjà présent,
        // sinon bouton d'ajout.
        if (existing != null)
          _CollectionControls(item: existing!)
        else
          FilledButton.icon(
            onPressed: () => _addToCollection(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter à ma collection'),
          ),
        if (details.overview.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Synopsis', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(details.overview),
        ],
        if (details.trailers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Bandes-annonces', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...details.trailers.map((v) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_fill),
                title: Text(v.name),
                onTap: () => launchUrl(Uri.parse(v.youtubeUrl),
                    mode: LaunchMode.externalApplication),
              )),
        ],
        if (details.cast.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Casting', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: details.cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final c = details.cast[i];
                return SizedBox(
                  width: 96,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: c.id == 0
                        ? null
                        : () => openPerson(
                              context,
                              ref,
                              id: c.id,
                              name: c.name,
                              profilePath: c.profilePath,
                            ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 96,
                          height: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: PosterImage(
                                posterPath: c.profilePath, size: 'w185'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(c.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall),
                        if (c.character.isNotEmpty)
                          Text(c.character,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Contrôles éditables d'un film présent dans la collection : possédé (+ date
/// d'acquisition), dates de visionnage (multiples), note. Tout est **enregistré
/// automatiquement**. + suppression.
class _CollectionControls extends ConsumerStatefulWidget {
  const _CollectionControls({required this.item});

  final CollectionItem item;

  @override
  ConsumerState<_CollectionControls> createState() =>
      _CollectionControlsState();
}

class _CollectionControlsState extends ConsumerState<_CollectionControls> {
  late bool _owned = widget.item.owned;
  late DateTime? _ownedAt = widget.item.ownedAt;
  late double _rating = widget.item.userRating ?? 0;
  late final List<DateTime> _watchDates = [...widget.item.watchDates];

  late final CollectionRepository _repo =
      ref.read(collectionRepositoryProvider);

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<DateTime?> _pickDate({DateTime? initial}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
  }

  Future<void> _save() async {
    try {
      await _repo.update(widget.item.copyWith(
        owned: _owned,
        ownedAt: _ownedAt,
        clearOwnedAt: !_owned || _ownedAt == null,
        userRating: _rating > 0 ? _rating : null,
        clearRating: _rating == 0,
        watchDates: List.of(_watchDates),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _addWatchDate() async {
    final picked = await _pickDate();
    if (picked == null) return;
    setState(() => _watchDates.add(picked));
    _save();
  }

  Future<void> _editOwnedDate() async {
    final picked = await _pickDate(initial: _ownedAt);
    if (picked == null) return;
    setState(() => _ownedAt = picked);
    _save();
  }

  Future<void> _delete() async {
    if (widget.item.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content:
            Text('Retirer « ${widget.item.title} » de votre collection ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.delete(widget.item.id!);
      // Ferme la fiche : dépile (grand écran) et pop la route (mobile).
      popDetail(ref);
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_done_outlined,
                    size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Text('Dans votre collection · enregistré automatiquement',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Possédé'),
              value: _owned,
              onChanged: (v) {
                setState(() {
                  _owned = v;
                  if (v) _ownedAt ??= DateTime.now();
                });
                _save();
              },
            ),
            if (_owned)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.event_available,
                        size: 18, color: theme.colorScheme.outline),
                    const SizedBox(width: 8),
                    Text(_ownedAt != null
                        ? 'Acquis le ${_fmt(_ownedAt!)}'
                        : 'Date d\'acquisition non définie'),
                    const Spacer(),
                    TextButton(
                      onPressed: _editOwnedDate,
                      child: Text(_ownedAt != null ? 'Modifier' : 'Définir'),
                    ),
                  ],
                ),
              ),
            const Divider(),
            // Visionnages (un film peut être vu plusieurs fois).
            Row(
              children: [
                Expanded(
                  child: Text('Visionnages (${_watchDates.length})',
                      style: theme.textTheme.titleSmall),
                ),
                TextButton.icon(
                  onPressed: _addWatchDate,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            if (_watchDates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Aucun visionnage enregistré.',
                    style: theme.textTheme.bodySmall),
              )
            else
              ...(_watchDates.toList()..sort((a, b) => b.compareTo(a)))
                  .map((d) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.visibility, size: 20),
                        title: Text('Vu le ${_fmt(d)}'),
                        trailing: IconButton(
                          tooltip: 'Retirer ce visionnage',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() => _watchDates.remove(d));
                            _save();
                          },
                        ),
                      )),
            const Divider(),
            Row(
              children: [
                const Text('Ma note'),
                Expanded(
                  child: Slider(
                    value: _rating,
                    min: 0,
                    max: 10,
                    divisions: 20,
                    label:
                        _rating == 0 ? 'Aucune' : _rating.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _rating = v),
                    onChangeEnd: (_) => _save(),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _rating == 0 ? '—' : _rating.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer de la collection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
