import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../tmdb/models/media_details.dart';
import '../../widgets/poster_image.dart';
import '../home/selected_media.dart';

/// Grille du casting, repliée à [maxCollapsed] vignettes avec un bouton « +N ».
class CastSection extends ConsumerStatefulWidget {
  const CastSection({super.key, required this.cast, this.maxCollapsed = 12});

  final List<CastMember> cast;
  final int maxCollapsed;

  @override
  ConsumerState<CastSection> createState() => _CastSectionState();
}

class _CastSectionState extends ConsumerState<CastSection> {
  int get _maxCollapsed => widget.maxCollapsed;

  bool _expanded = false;

  Widget _tile(CastMember c) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: c.id == 0
            ? null
            : () => openPerson(context, ref, id: c.id, name: c.name, profilePath: c.profilePath),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 96,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PosterImage(posterPath: c.profilePath, size: 'w185'),
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
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _expanded = true),
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
              child: Text('+$hidden',
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
    final theme = Theme.of(context);
    final cast = widget.cast;
    final overflowing = cast.length > _maxCollapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.l10n.detailsCastTitle(cast.length),
                  style: theme.textTheme.titleMedium),
            ),
            if (_expanded)
              TextButton(
                onPressed: () => setState(() => _expanded = false),
                child: Text(context.l10n.detailsCollapse),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final c in _expanded ? cast : cast.take(_maxCollapsed)) _tile(c),
            if (overflowing && !_expanded) _moreTile(cast.length - _maxCollapsed),
          ],
        ),
      ],
    );
  }
}
