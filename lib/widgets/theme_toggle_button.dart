import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import '../core/theme/theme_mode_controller.dart';

/// Bouton (menu) de sélection du thème : Système / Clair / Sombre.
/// À placer dans les `actions` d'une AppBar.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final l10n = context.l10n;
    return PopupMenuButton<ThemeMode>(
      tooltip: l10n.themeTooltip,
      icon: Icon(_iconFor(mode)),
      initialValue: mode,
      onSelected: (m) => ref.read(themeModeProvider.notifier).set(m),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ThemeMode.system,
          child: ListTile(
            leading: const Icon(Icons.brightness_auto),
            title: Text(l10n.themeSystem),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.light,
          child: ListTile(
            leading: const Icon(Icons.light_mode),
            title: Text(l10n.themeLight),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: ListTile(
            leading: const Icon(Icons.dark_mode),
            title: Text(l10n.themeDark),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  IconData _iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.system => Icons.brightness_auto,
      };
}
