import 'package:flutter/material.dart';

import 'poster_image.dart';

/// Ouvre l'image [posterPath] en plein écran (fond noir, zoom/déplacement).
/// [heroTag], si fourni, anime la transition depuis la vignette d'origine.
Future<void> showImageViewer(
  BuildContext context, {
  required String? posterPath,
  Object? heroTag,
}) {
  if (posterPath == null || posterPath.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: animation,
        child: _ImageViewerPage(posterPath: posterPath, heroTag: heroTag),
      ),
    ),
  );
}

/// Affiche/vignette cliquable qui ouvre l'image en plein écran (zoom/pan) via
/// [showImageViewer], avec une transition Hero. Sans image, rien de cliquable.
class TappablePoster extends StatelessWidget {
  const TappablePoster({
    super.key,
    required this.posterPath,
    required this.width,
    required this.height,
    this.size = 'w342',
    this.borderRadius = 8,
  });

  final String? posterPath;
  final double width;
  final double height;
  final String size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final hasImage = posterPath != null && posterPath!.isNotEmpty;
    final tag = 'poster:$posterPath';
    Widget poster = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: PosterImage(posterPath: posterPath, size: size),
    );
    if (hasImage) poster = Hero(tag: tag, child: poster);
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: hasImage
              ? () => showImageViewer(context,
                  posterPath: posterPath, heroTag: tag)
              : null,
          child: poster,
        ),
      ),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.posterPath, this.heroTag});

  final String posterPath;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    Widget image = InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: PosterImage(
          posterPath: posterPath,
          size: 'original',
          fit: BoxFit.contain,
        ),
      ),
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tap hors de l'image (ou dessus quand non zoomée) pour fermer.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: image,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
