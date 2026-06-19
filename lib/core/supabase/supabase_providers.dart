import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client Supabase global (initialisé dans `main.dart` via `Supabase.initialize`).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Flux des changements d'état d'authentification (connexion/déconnexion).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Session courante (null si non connecté). Recalculée à chaque changement d'auth.
final currentSessionProvider = Provider<Session?>((ref) {
  // On écoute les changements pour invalider ce provider.
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});

/// Utilisateur courant (null si non connecté).
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(currentSessionProvider)?.user;
});
