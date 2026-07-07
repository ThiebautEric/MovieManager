import 'package:flutter/material.dart';

import '../data/models/film.dart';

/// Couleur distinctive du support (fond de la pastille).
extension MediumUi on Medium {
  Color get color => switch (this) {
        Medium.dvd => const Color(0xFF546E7A), // gris-bleu (DVD)
        Medium.bluray => const Color(0xFF1565C0), // bleu vif (Blu-ray)
        Medium.digital => const Color(0xFF00897B), // turquoise (Digital)
      };
}

/// Pastille du support de possession (DVD / Blu-ray / Digital), à poser en haut
/// à gauche d'une affiche.
class MediumBadge extends StatelessWidget {
  const MediumBadge({super.key, required this.medium, this.compact = false});

  final Medium medium;

  /// Version plus petite (pour les petites vignettes).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6, vertical: compact ? 1 : 2),
      decoration: BoxDecoration(
        color: medium.color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(medium.icon, size: compact ? 10 : 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            medium.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 8 : 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
