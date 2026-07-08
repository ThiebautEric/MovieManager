import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/supabase/view_as.dart';
import '../models/favorite_person.dart';
import 'collection_repository.dart' show sharedPreferencesProvider;

/// Personnes favorites (acteurs/réalisateurs). En mode cloud : table `favorites`
/// de Supabase (temps réel) ; en mode local : `shared_preferences`.
/// Triées du plus récemment ajouté au plus ancien.
class FavoritesController extends Notifier<List<FavoritePerson>> {
  static const _key = 'favorite_persons_v1';
  static const _table = 'favorites';

  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  List<FavoritePerson> build() {
    ref.onDispose(() => _sub?.cancel());
    if (AppConfig.hasSupabase) {
      ref.watch(currentUserProvider); // reset/re-souscrit au changement d'auth
      // Consultation admin : select one-shot des favoris de la cible (pas de
      // realtime — inutile en lecture seule et fragile avec les claims JWT).
      final target = ref.watch(viewAsProvider);
      if (target != null) {
        _loadOnce(target.userId);
        return const [];
      }
      _subscribeCloud();
      return const [];
    }
    return _loadLocal();
  }

  SupabaseClient get _client => ref.read(supabaseClientProvider);
  String? get _uid => _client.auth.currentUser?.id;

  bool isFavorite(int personId) => state.any((e) => e.personId == personId);

  static List<FavoritePerson> _sortDesc(List<FavoritePerson> list) =>
      [...list]..sort((a, b) =>
          (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)));

  // --- Cloud --------------------------------------------------------------
  void _subscribeCloud() {
    final uid = _uid;
    if (uid == null) return;
    _sub?.cancel();
    _sub = _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .listen((rows) {
      state = _sortDesc(rows.map(FavoritePerson.fromJson).toList());
    });
  }

  Future<void> _loadOnce(String uid) async {
    final rows = await _client.from(_table).select().eq('user_id', uid);
    state = _sortDesc(
        rows.cast<Map<String, dynamic>>().map(FavoritePerson.fromJson).toList());
  }

  // --- Local --------------------------------------------------------------
  List<FavoritePerson> _loadLocal() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => FavoritePerson.fromJson(e as Map<String, dynamic>))
        .toList();
    return _sortDesc(list);
  }

  Future<void> _persistLocal() async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  /// Ajoute ou retire la personne des favoris.
  Future<void> toggle({
    required int personId,
    required String name,
    String? profilePath,
  }) async {
    if (ref.read(viewAsProvider) != null) return; // lecture seule (admin)
    final removing = isFavorite(personId);
    // Mise à jour optimiste (l'UI répond tout de suite).
    state = removing
        ? state.where((e) => e.personId != personId).toList()
        : [
            FavoritePerson(
              personId: personId,
              name: name,
              profilePath: profilePath,
              addedAt: DateTime.now(),
            ),
            ...state,
          ];

    if (AppConfig.hasSupabase) {
      final uid = _uid;
      if (uid == null) return;
      try {
        if (removing) {
          await _client
              .from(_table)
              .delete()
              .eq('user_id', uid)
              .eq('person_id', personId);
        } else {
          await _client.from(_table).insert({
            'user_id': uid,
            'person_id': personId,
            'name': name,
            'profile_path': profilePath,
          });
        }
      } catch (_) {
        // En cas d'échec réseau, le flux temps réel recalera l'état.
      }
    } else {
      await _persistLocal();
    }
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, List<FavoritePerson>>(
        FavoritesController.new);

/// Vrai si la personne donnée est en favori (réactif).
final isFavoriteProvider = Provider.family<bool, int>((ref, personId) {
  return ref.watch(favoritesProvider).any((e) => e.personId == personId);
});
