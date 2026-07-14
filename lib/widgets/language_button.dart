import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import '../core/l10n/locale_controller.dart';

/// Bouton (menu) de sélection de la langue : Système / Français / Deutsch /
/// English. À placer dans les `actions` d'une AppBar.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(appLocaleProvider);
    final l10n = context.l10n;
    // Les noms de langues restent dans leur propre langue (usage standard).
    final entries = <(String, String)>[
      ('system', l10n.languageSystem),
      ('fr', 'Français'),
      ('de', 'Deutsch'),
      ('en', 'English'),
    ];
    final current = chosen?.languageCode ?? 'system';
    return PopupMenuButton<String>(
      tooltip: l10n.languageTooltip,
      icon: const Icon(Icons.language),
      initialValue: current,
      onSelected: (code) => ref.read(appLocaleProvider.notifier).set(
            code == 'system' ? null : Locale(code),
          ),
      itemBuilder: (context) => [
        for (final (code, label) in entries)
          PopupMenuItem(
            value: code,
            child: ListTile(
              leading: Icon(code == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(label),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}
