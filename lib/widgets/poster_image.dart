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
