import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/supabase/view_as.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/language_button.dart';
import '../../widgets/original_title_button.dart';
import '../../widgets/theme_toggle_button.dart';
import 'friends_controller.dart';

/// Écran « Mes amis » : les autres comptes de l'app. Un clic ouvre leur
/// bibliothèque en consultation (lecture seule, bandeau + bouton Quitter).
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.friendsTitle),
        actions: const [
          OriginalTitleButton(),
          LanguageButton(),
          ThemeToggleButton(),
        ],
      ),
      body: switch (async) {
        AsyncData(:final value) when value.isEmpty => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.friendsEmpty,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.read(friendsProvider.notifier).reload(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: value.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final f = value[i];
                final email = f.email ?? context.l10n.friendsNoEmail;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(email, overflow: TextOverflow.ellipsis),
                  subtitle: Text(context.l10n.friendsViewLibrary),
                  trailing: const Icon(Icons.visibility_outlined),
                  onTap: () => ref.read(viewAsProvider.notifier).enter(
                        ViewAsTarget(userId: f.userId, email: email),
                      ),
                );
              },
            ),
          ),
        AsyncError(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(context.l10n.friendsLoadError('$error'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(friendsProvider),
                  child: Text(context.l10n.friendsRetry),
                ),
              ],
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
