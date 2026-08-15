import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../tmdb/tmdb_client.dart';

/// Affiche TMDB avec cache disque et fallback si l'image est absente.
///
/// Le [memCacheWidth] est calculé automatiquement : si la largeur physique
/// d'affichage est inférieure à la résolution source TMDB (ex. w342 = 342px),
/// on stocke l'image décodée à la taille d'affichage réelle. Cela multiplie
/// la capacité du cache mémoire sans sacrifier la qualité visuelle.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.posterPath,
    this.size = 'w342',
    this.fit = BoxFit.cover,
  });

  final String? posterPath;
  final String size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = TmdbClient.imageUrl(posterPath, size: size);
    if (url == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.movie, size: 40)),
      );
    }
    // Largeur source TMDB extraite du paramètre size ('w342' → 342).
    final sourceWidth = int.tryParse(size.replaceFirst('w', ''));
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcule la largeur physique d'affichage. On ne restreint que si elle
        // est strictement inférieure à la résolution source, pour éviter tout
        // upscale qui consommerait plus de mémoire qu'une image source native.
        int? memWidth;
        if (sourceWidth != null && !constraints.maxWidth.isInfinite) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final physical = (constraints.maxWidth * dpr).round();
          if (physical < sourceWidth) memWidth = physical;
        }
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          memCacheWidth: memWidth,
          placeholder: (_, _) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (_, _, _) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.broken_image, size: 40)),
          ),
        );
      },
    );
  }
}
