import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import '../core/prefs/original_titles_controller.dart';

/// Fait défiler le mode d'affichage des titres : traduit (langue de l'appli)
/// → original (VO) → anglais. À placer dans les `actions` d'une AppBar.
class OriginalTitleButton extends ConsumerWidget {
  const OriginalTitleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(titleDisplayModeProvider);
    final l10n = context.l10n;
    final label = switch (mode) {
      TitleDisplayMode.localized =>
        Localizations.localeOf(context).languageCode.toUpperCase(),
      TitleDisplayMode.original => l10n.titleModeOriginalShort,
      TitleDisplayMode.english => 'EN',
    };
    final tooltip = switch (mode) {
      TitleDisplayMode.localized => l10n.titleModeLocalizedTooltip,
      TitleDisplayMode.original => l10n.titleModeOriginalTooltip,
      TitleDisplayMode.english => l10n.titleModeEnglishTooltip,
    };
    return IconButton(
      tooltip: tooltip,
      onPressed: () => ref.read(titleDisplayModeProvider.notifier).cycle(),
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.translate, size: 16),
          const SizedBox(width: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
