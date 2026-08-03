import 'package:flutter/material.dart';

/// Bandeau vertical affiché sur la bordure gauche d'une affiche de série.
/// [watched] = numéros de saisons vues (jaune/ambre).
/// [known]   = numéros de saisons connues mais non vues (gris).
/// [current] = saison mise en valeur (fond rouge).
class SeasonBand extends StatelessWidget {
  const SeasonBand({super.key, required this.watched, this.known = const {}, this.current});

  final Set<int> watched;
  final Set<int> known;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final all = <int>{...watched, ...known}.toList()..sort();
    if (all.isEmpty) return const SizedBox.shrink();

    final count = all.length;

    final int cols;
    final double dotSize;
    final double fontSize;
    if (count <= 8) {
      cols = 1; dotSize = 18; fontSize = 9;
    } else if (count <= 12) {
      cols = 1; dotSize = 15; fontSize = 8;
    } else if (count <= 20) {
      cols = 2; dotSize = 13; fontSize = 7;
    } else {
      cols = 3; dotSize = 11; fontSize = 6.5;
    }

    final perCol = (count / cols).ceil();
    // largeur = padding horizontal (3×2) + colonnes + gaps entre colonnes
    final bandWidth = 6.0 + cols * dotSize + (cols - 1) * 3.0;

    Widget dot(int season) => Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: season == current
                ? Colors.red.shade600
                : watched.contains(season)
                    ? Colors.amber
                    : Colors.grey.shade500,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$season',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(8),
        bottomLeft: Radius.circular(8),
      ),
      child: Container(
        width: bandWidth,
        color: Colors.black.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int c = 0; c < cols; c++) ...[
              if (c > 0) const SizedBox(width: 3),
              Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int r = 0; r < perCol; r++)
                    if (c * perCol + r < count) dot(all[c * perCol + r]),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
