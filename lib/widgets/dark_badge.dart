import 'package:flutter/material.dart';

/// Badge semi-transparent (fond noir 65 %) avec une icône et un libellé optionnel.
/// Utilisé sur les affiches pour la note, le format support, la saison, etc.
class DarkBadge extends StatelessWidget {
  const DarkBadge({super.key, required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: label == null ? 4 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          if (label != null) ...[
            const SizedBox(width: 2),
            Text(label!,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
