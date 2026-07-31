import 'package:flutter/material.dart';

/// Bandeau vertical affiché sur la bordure gauche d'une affiche de série.
/// [watched] = numéros de saisons vues (jaune/ambre).
/// [known] = numéros de saisons connues mais non vues (gris).
class SeasonBand extends StatelessWidget {
  const SeasonBand({super.key, required this.watched, this.known = const {}});

  final Set<int> watched;
  final Set<int> known;

  @override
  Widget build(BuildContext context) {
    final all = <int>{...watched, ...known}.toList()..sort();
    if (all.isEmpty) return const SizedBox.shrink();

    final count = all.length;
    final dotSize = count <= 8 ? 18.0 : count <= 12 ? 15.0 : 12.0;
    final fontSize = count <= 8 ? 9.0 : count <= 12 ? 8.0 : 7.0;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(8),
        bottomLeft: Radius.circular(8),
      ),
      child: Container(
        width: dotSize + 6,
        color: Colors.black.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < all.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: watched.contains(all[i])
                      ? Colors.amber
                      : Colors.grey.shade500,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${all[i]}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
