import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/view_as.dart';
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
        title: const Text('Mes amis'),
        actions: const [ThemeToggleButton()],
      ),
      body: switch (async) {
        AsyncData(:final value) when value.isEmpty => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun autre utilisateur pour le moment.',
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
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(f.email, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Voir sa bibliothèque (lecture seule)'),
                  trailing: const Icon(Icons.visibility_outlined),
                  onTap: () => ref.read(viewAsProvider.notifier).enter(
                        ViewAsTarget(userId: f.userId, email: f.email),
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
                Text('Chargement impossible : $error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(friendsProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
