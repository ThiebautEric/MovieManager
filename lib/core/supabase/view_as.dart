import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_providers.dart';

/// Cible du mode « consultation » : l'admin regarde la bibliothèque d'un autre
/// utilisateur, en lecture seule (les politiques RLS n'accordent que SELECT).
class ViewAsTarget {
  const ViewAsTarget({required this.userId, required this.email});

  final String userId;
  final String email;
}

/// État du mode consultation. `null` = mode normal (ses propres données).
class ViewAsController extends Notifier<ViewAsTarget?> {
  @override
  ViewAsTarget? build() {
    // Toute variation d'auth (déconnexion, changement de compte) met fin à la
    // consultation : le provider est reconstruit à null.
    ref.watch(currentUserProvider);
    return null;
  }

  void enter(ViewAsTarget target) => state = target;

  void exit() => state = null;
}

final viewAsProvider =
    NotifierProvider<ViewAsController, ViewAsTarget?>(ViewAsController.new);

/// Vrai quand l'admin consulte la bibliothèque d'un autre utilisateur.
final isViewingAsProvider =
    Provider<bool>((ref) => ref.watch(viewAsProvider) != null);

/// Vrai si l'utilisateur connecté porte la claim admin (`app_metadata.role`).
/// La claim est posée côté serveur (supabase/admin.sql) et arrive via le JWT.
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.appMetadata['role'] == 'admin';
});
