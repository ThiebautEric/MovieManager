import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';

/// Actions d'authentification (connexion, inscription, déconnexion).
class AuthController {
  AuthController(this._client);

  final SupabaseClient _client;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Inscription. Renvoie true si une confirmation par e-mail est requise
  /// (aucune session active immédiatement).
  Future<bool> signUp(String email, String password) async {
    final res =
        await _client.auth.signUp(email: email, password: password);
    return res.session == null;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(supabaseClientProvider));
});
