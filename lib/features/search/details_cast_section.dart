import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../tmdb/models/media_details.dart';
import '../../widgets/poster_image.dart';
import '../home/selected_media.dart';

/// Grille du casting, initialement repliée à 12 vignettes.
/// Chaque clic sur « +N » affiche 20 entrées de plus.
class CastSection extends ConsumerStatefulWidget {
  const CastSection({super.key, required this.cast});

  final List<CastMember> cast;

  @override
  ConsumerState<CastSection> createState() => _CastSectionState();
}

class _CastSectionState extends ConsumerState<CastSection>
    with AutomaticKeepAliveClientMixin {
  static const _initial = 12;
  static const _step = 20;

  int _shown = _initial;

  @override
  bool get wantKeepAlive => true;

  Widget _tile(CastMember c) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: c.id == 0
            ? null
            : () => openPerson(context, ref,
                id: c.id, name: c.name, profilePath: c.profilePath),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 96,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PosterImage(posterPath: c.profilePath),
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(int hidden) {
    final theme = Theme.of(context);
    final next = hidden.clamp(0, _step);
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _shown += _step),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('+$next',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
            const SizedBox(height: 4),
            Text(context.l10n.detailsShowAll,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cast = widget.cast;
    final hasMore = _shown < cast.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.l10n.detailsCastTitle(cast.length),
                  style: theme.textTheme.titleMedium),
            ),
            if (_shown > _initial)
              TextButton(
                onPressed: () => setState(() => _shown = _initial),
                child: Text(context.l10n.detailsCollapse),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final c in cast.take(_shown)) _tile(c),
            if (hasMore) _moreTile(cast.length - _shown),
          ],
        ),
      ],
    );
  }
}
