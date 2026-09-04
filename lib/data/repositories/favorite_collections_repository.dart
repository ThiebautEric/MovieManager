import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/supabase/view_as.dart';
import '../models/favorite_collection.dart';
import 'collection_repository.dart' show sharedPreferencesProvider;

/// Sagas favorites (collections TMDB de films). En mode cloud : table
/// `favorite_collections` de Supabase (temps réel) ; en mode local :
/// `shared_preferences`. Triées du plus récemment ajouté au plus ancien.
///
/// Calqué à l'identique sur [FavoritesController] (personnes).
class FavoriteCollectionsController
    extends Notifier<List<FavoriteCollection>> {
  static const _key = 'favorite_collections_v1';
  static const _table = 'favorite_collections';

  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  List<FavoriteCollection> build() {
    ref.onDispose(() => _sub?.cancel());
    if (AppConfig.hasSupabase) {
      ref.watch(currentUserProvider); // reset/re-souscrit au changement d'auth
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

  bool isFavorite(int collectionId) =>
      state.any((e) => e.collectionId == collectionId);

  static List<FavoriteCollection> _sortDesc(List<FavoriteCollection> list) {
    // Dédoublonnage par collection_id (identité réelle), plus récent gardé.
    final byId = <int, FavoriteCollection>{};
    for (final f in list) {
      final cur = byId[f.collectionId];
      if (cur == null ||
          (f.addedAt ?? DateTime(0)).isAfter(cur.addedAt ?? DateTime(0))) {
        byId[f.collectionId] = f;
      }
    }
    return byId.values.toList()
      ..sort((a, b) =>
          (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)));
  }

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
      state = _sortDesc(rows.map(FavoriteCollection.fromJson).toList());
    });
  }

  Future<void> _loadOnce(String uid) async {
    final rows = await _client.from(_table).select().eq('user_id', uid);
    state = _sortDesc(rows
        .cast<Map<String, dynamic>>()
        .map(FavoriteCollection.fromJson)
        .toList());
  }

  // --- Local --------------------------------------------------------------
  List<FavoriteCollection> _loadLocal() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => FavoriteCollection.fromJson(e as Map<String, dynamic>))
        .toList();
    return _sortDesc(list);
  }

  Future<void> _persistLocal() async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  /// Ajoute ou retire la saga des favoris.
  Future<void> toggle({
    required int collectionId,
    required String name,
    String? posterPath,
  }) async {
    if (ref.read(viewAsProvider) != null) return; // lecture seule (admin)
    final removing = isFavorite(collectionId);
    state = removing
        ? state.where((e) => e.collectionId != collectionId).toList()
        : [
            FavoriteCollection(
              collectionId: collectionId,
              name: name,
              posterPath: posterPath,
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
              .eq('collection_id', collectionId);
        } else {
          await _client.from(_table).upsert({
            'user_id': uid,
            'collection_id': collectionId,
            'name': name,
            'poster_path': posterPath,
          }, onConflict: 'user_id,collection_id');
        }
      } catch (_) {
        // En cas d'échec réseau, le flux temps réel recalera l'état.
      }
    } else {
      await _persistLocal();
    }
  }
}

final favoriteCollectionsProvider =
    NotifierProvider<FavoriteCollectionsController, List<FavoriteCollection>>(
        FavoriteCollectionsController.new);

/// Vrai si la saga donnée est en favori (réactif).
final isFavoriteCollectionProvider = Provider.family<bool, int>((ref, id) {
  return ref
      .watch(favoriteCollectionsProvider)
      .any((e) => e.collectionId == id);
});
