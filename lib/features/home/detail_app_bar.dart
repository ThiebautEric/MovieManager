import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'selected_media.dart';

/// Bouton de gauche d'une fiche (film ou personne).
///
/// - mobile (route poussée) : flèche retour standard qui dépile la route ;
/// - grand écran (pile maître-détail) : flèche retour si une fiche précédente
///   existe, sinon une croix qui ferme la pile.
class DetailLeadingButton extends ConsumerWidget {
  const DetailLeadingButton({super.key, required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!embedded) return const BackButton();

    final depth = ref.watch(detailStackProvider).length;
    if (depth > 1) {
      return IconButton(
        tooltip: 'Retour',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => popDetail(ref),
      );
    }
    return IconButton(
      tooltip: 'Fermer',
      icon: const Icon(Icons.close),
      onPressed: () => closeDetail(ref),
    );
  }
}
