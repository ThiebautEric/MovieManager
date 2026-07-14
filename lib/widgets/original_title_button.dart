import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import '../core/prefs/original_titles_controller.dart';

/// Bascule l'affichage des titres : localisés ↔ originaux.
/// À placer dans les `actions` d'une AppBar.
class OriginalTitleButton extends ConsumerWidget {
  const OriginalTitleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(showOriginalTitlesProvider);
    return IconButton(
      tooltip: on
          ? context.l10n.originalTitlesOffTooltip
          : context.l10n.originalTitlesOnTooltip,
      isSelected: on,
      icon: const Icon(Icons.translate),
      onPressed: () =>
          ref.read(showOriginalTitlesProvider.notifier).toggle(),
    );
  }
}
