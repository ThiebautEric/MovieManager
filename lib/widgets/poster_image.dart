import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../tmdb/tmdb_client.dart';

/// Affiche TMDB avec cache disque et fallback si l'image est absente.
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
    return CachedNetworkImage(
      imageUrl: url,
      // Pour w342 : réduit de ~700 KB à ~240 KB en mémoire (200×300×4 octets).
      // Pas appliqué pour les petits formats (w185, w92…) où la source est déjà
      // plus petite que 200 px et ResizeImage se comporterait de façon imprévisible.
      memCacheWidth: size == 'w342' ? 200 : null,
      fit: fit,
      placeholder: (_, _) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, _, _) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.broken_image, size: 40)),
      ),
    );
  }
}
