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

    // Toujours 10 slots par colonne, du haut vers le bas.
    // Taille de pastille fixe (identique à 1 colonne / peu de saisons).
    const int perCol = 7;
    final int cols = count <= 7 ? 1 : count <= 14 ? 2 : 3;
    const double dotSize = 18;
    const double fontSize = 9;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int c = 0; c < cols; c++) ...[
              if (c > 0) const SizedBox(width: 3),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (int r = 0; r < perCol; r++) ...[
                    if (r > 0) const SizedBox(height: 2),
                    if (c * perCol + r < count)
                      dot(all[c * perCol + r])
                    else
                      SizedBox(width: dotSize, height: dotSize),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
