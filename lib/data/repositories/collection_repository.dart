import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_providers.dart';
import '../models/collection_item.dart';

/// Contrat commun aux deux backends (cloud Supabase / local appareil).
abstract class CollectionRepository {
  Stream<List<CollectionItem>> watchAll();
  Future<void> upsert(CollectionItem item);
  Future<void> update(CollectionItem item);
  Future<void> delete(String id);

  /// Resynchronise la liste avec la source de vérité (utile pour récupérer les
  /// changements faits depuis un autre appareil, non reçus en temps réel).
  Future<void> refresh();
}

/// Backend cloud : table `collection_items` de Supabase (auth + synchro).
///
/// Maintient un cache local mis à jour de façon **optimiste** à chaque
/// mutation : l'UI se met à jour immédiatement (sans attendre/dépendre des
/// événements temps réel, peu fiables pour les suppressions). Le flux temps
/// réel sert en plus à recevoir les changements faits depuis un autre appareil.
class SupabaseCollectionRepository implements CollectionRepository {
  SupabaseCollectionRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'collection_items';

  List<CollectionItem> _cache = const [];
  StreamController<List<CollectionItem>>? _controller;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Aucun utilisateur connecté.');
    }
    return id;
  }

  void _emit() => _controller?.add(List.unmodifiable(_cache));

  void _sortCache() {
    _cache.sort((a, b) => (a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
  }

  @override
  Stream<List<CollectionItem>> watchAll() {
    _controller ??= StreamController<List<CollectionItem>>.broadcast(
      onCancel: () {
        _sub?.cancel();
        _sub = null;
        _controller?.close();
        _controller = null;
      },
    );
    // Temps réel : reflète les changements externes (autres appareils).
    _sub ??= _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('added_at')
        .listen((rows) {
      _cache = rows.map(CollectionItem.fromJson).toList();
      _emit();
    });
    return _controller!.stream;
  }

  @override
  Future<void> upsert(CollectionItem item) async {
    final payload = {...item.toUpsertJson(), 'user_id': _userId};
    final row = await _client
        .from(_table)
        .upsert(payload, onConflict: 'user_id,tmdb_id,media_type')
        .select()
        .single();
    final saved = CollectionItem.fromJson(row);
    _cache = [
      ..._cache.where((e) =>
          !(e.tmdbId == saved.tmdbId && e.mediaType == saved.mediaType)),
      saved,
    ];
    _sortCache();
    _emit();
  }

  @override
  Future<void> update(CollectionItem item) async {
    if (item.id == null) return upsert(item);
    await _client
        .from(_table)
        .update(item.toUpsertJson())
        .eq('id', item.id!)
        .eq('user_id', _userId);
    // Mise à jour optimiste du cache.
    _cache = _cache.map((e) => e.id == item.id ? item : e).toList();
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id).eq('user_id', _userId);
    // Retrait optimiste immédiat (ne dépend pas du temps réel).
    _cache = _cache.where((e) => e.id != id).toList();
    _emit();
  }

  @override
  Future<void> refresh() async {
    // Récupère la vérité côté serveur (supprime les éventuels « fantômes »
    // laissés par des suppressions faites depuis un autre appareil).
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .order('added_at');
    _cache = rows
        .map((e) => CollectionItem.fromJson(e))
        .toList();
    _emit();
  }
}

/// Backend local : collection persistée sur l'appareil (sans compte ni synchro).
class LocalCollectionRepository implements CollectionRepository {
  LocalCollectionRepository(this._prefs) {
    _items = _load();
    _controller.add(_snapshot());
  }

  final SharedPreferences _prefs;
  static const _key = 'local_collection_v1';

  late List<CollectionItem> _items;
  final _controller = StreamController<List<CollectionItem>>.broadcast();

  String _idFor(CollectionItem i) => '${i.mediaType}_${i.tmdbId}';

  List<CollectionItem> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List<dynamic>);
    return list
        .map((e) => CollectionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persist() async {
    await _prefs.setString(
        _key, jsonEncode(_items.map((e) => e.toFullJson()).toList()));
    _controller.add(_snapshot());
  }

  List<CollectionItem> _snapshot() => List.unmodifiable(_items);

  @override
  Stream<List<CollectionItem>> watchAll() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<void> upsert(CollectionItem item) async {
    final id = item.id ?? _idFor(item);
    final withId = CollectionItem(
      id: id,
      tmdbId: item.tmdbId,
      mediaType: item.mediaType,
      title: item.title,
      posterPath: item.posterPath,
      releaseYear: item.releaseYear,
      genres: item.genres,
      owned: item.owned,
      userRating: item.userRating,
      notes: item.notes,
      addedAt: item.addedAt ?? DateTime.now(),
      ownedAt: item.ownedAt,
      watchDates: item.watchDates,
    );
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _items[idx] = withId;
    } else {
      _items.add(withId);
    }
    await _persist();
  }

  @override
  Future<void> update(CollectionItem item) => upsert(item);

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<void> refresh() async {
    _items = _load();
    _controller.add(_snapshot());
  }
}

/// SharedPreferences injecté depuis `main()` (override du ProviderScope) en mode local.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider non initialisé'),
);

/// Renvoie le bon backend selon la configuration (cloud si Supabase, sinon local).
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  if (AppConfig.hasSupabase) {
    return SupabaseCollectionRepository(ref.watch(supabaseClientProvider));
  }
  return LocalCollectionRepository(ref.watch(sharedPreferencesProvider));
});

/// Flux de la collection (réinitialisé au changement d'auth en mode cloud).
final collectionStreamProvider = StreamProvider<List<CollectionItem>>((ref) {
  if (AppConfig.hasSupabase) {
    ref.watch(currentUserProvider);
  }
  return ref.watch(collectionRepositoryProvider).watchAll();
});
