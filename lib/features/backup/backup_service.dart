import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';

class BackupStats {
  const BackupStats({
    required this.films,
    required this.seasons,
    required this.history,
    required this.collection,
    required this.wishlist,
    required this.favorites,
  });

  final int films;
  final int seasons;
  final int history;
  final int collection;
  final int wishlist;
  final int favorites;
}

class BackupService {
  const BackupService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, (i + size).clamp(0, list.length));
    }
  }

  Future<List<Map<String, dynamic>>> _selectAll(String table) async {
    const pageSize = 1000;
    final out = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final rows = await _client
          .from(table)
          .select()
          .eq('user_id', _uid)
          .order('id')
          .range(from, from + pageSize - 1);
      final list = rows.cast<Map<String, dynamic>>();
      out.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }
    return out;
  }

  /// Exporte toutes les tables de l'utilisateur dans un fichier ZIP
  /// (un JSON par table : films, film_seasons, history, collection, wishlist, favorites).
  Future<Uint8List> export() async {
    final results = await Future.wait([
      _selectAll('films'),
      _selectAll('film_seasons'),
      _selectAll('history'),
      _selectAll('collection'),
      _selectAll('wishlist'),
      _selectAll('favorites'),
    ]);

    final arc = Archive();
    const names = [
      'films.json',
      'film_seasons.json',
      'history.json',
      'collection.json',
      'wishlist.json',
      'favorites.json',
    ];
    for (var i = 0; i < names.length; i++) {
      final bytes = utf8.encode(jsonEncode(results[i]));
      arc.addFile(ArchiveFile(names[i], bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(arc)!);
  }

  /// Importe un ZIP de sauvegarde dans le compte courant.
  ///
  /// Si [clearFirst] = true : efface d'abord toutes les données
  /// (recommandé pour une restauration complète, y compris sur un nouveau compte).
  /// Si [clearFirst] = false (fusion) : insère par-dessus les données existantes ;
  /// des doublons peuvent apparaître dans l'historique.
  ///
  /// Les UUIDs internes sont remappés via la clé naturelle (tmdb_id, media_type)
  /// pour les films, puis répercutés sur toutes les tables liées.
  Future<BackupStats> importZip(
    Uint8List zipBytes, {
    required bool clearFirst,
  }) async {
    final arc = ZipDecoder().decodeBytes(zipBytes);

    List<Map<String, dynamic>> readFile(String name) {
      final file = arc.findFile(name);
      if (file == null) return const [];
      return (jsonDecode(utf8.decode(file.content as List<int>)) as List)
          .cast<Map<String, dynamic>>();
    }

    final bFilms = readFile('films.json');
    final bSeasons = readFile('film_seasons.json');
    final bHistory = readFile('history.json');
    final bCollection = readFile('collection.json');
    final bWishlist = readFile('wishlist.json');
    final bFavorites = readFile('favorites.json');

    if (clearFirst) {
      // La suppression des films cascade sur film_seasons/collection/history/wishlist
      // via les FK ON DELETE CASCADE définies dans le schéma.
      await _client.from('films').delete().eq('user_id', _uid);
      await _client.from('favorites').delete().eq('user_id', _uid);
    }

    // --- Films : upsert + construction de la carte old_uuid → new_uuid ---
    // La clé naturelle (tmdb_id, media_type) permet de retrouver le nouvel UUID
    // après upsert, même si le compte cible est différent du compte source.
    final filmIdMap = <String, String>{};
    for (final chunk in _chunks(bFilms, 200)) {
      final keyToOldId = {
        for (final f in chunk)
          '${f['tmdb_id']}:${f['media_type']}': f['id'] as String,
      };
      final rows = chunk.map((f) {
        final r = Map<String, dynamic>.from(f)
          ..remove('id')
          ..remove('added_at'); // sera réinitialisé à now()
        r['user_id'] = _uid;
        return r;
      }).toList();
      final returned = await _client
          .from('films')
          .upsert(rows, onConflict: 'user_id,tmdb_id,media_type')
          .select('id,tmdb_id,media_type');
      for (final r in returned.cast<Map<String, dynamic>>()) {
        final key = '${r['tmdb_id']}:${r['media_type']}';
        final oldId = keyToOldId[key];
        if (oldId != null) filmIdMap[oldId] = r['id'] as String;
      }
    }

    // --- film_seasons ---
    int cntSeasons = 0;
    for (final chunk in _chunks(bSeasons, 200)) {
      final rows = chunk
          .where((s) => filmIdMap.containsKey(s['film_id']))
          .map((s) {
            final r = Map<String, dynamic>.from(s)..remove('id');
            r['film_id'] = filmIdMap[r['film_id']];
            r['user_id'] = _uid;
            return r;
          })
          .toList();
      if (rows.isEmpty) continue;
      await _client
          .from('film_seasons')
          .upsert(rows, onConflict: 'film_id,season_number');
      cntSeasons += rows.length;
    }

    // --- history : insert sans dépendance à l'ordre de retour ---
    int cntHistory = 0;
    for (final chunk in _chunks(bHistory, 200)) {
      final rows = chunk
          .where((h) => filmIdMap.containsKey(h['film_id']))
          .map((h) {
            final r = Map<String, dynamic>.from(h)
              ..remove('id')
              ..remove('created_at');
            r['film_id'] = filmIdMap[r['film_id']];
            r['user_id'] = _uid;
            return r;
          })
          .toList();
      if (rows.isEmpty) continue;
      await _client.from('history').insert(rows);
      cntHistory += rows.length;
    }

    // Carte old_uuid → new_uuid via clé naturelle (film_id, watched_at,
    // season_number, episode_number) — aucune dépendance à l'ordre PostgreSQL.
    final historyIdMap = <String, String>{};
    final allNewHistory = await _selectAll('history');
    final newHistByKey = <String, String>{};
    for (final row in allNewHistory) {
      final key = '${row['film_id']}|${row['watched_at']}'
          '|${row['season_number']}|${row['episode_number']}';
      newHistByKey[key] = row['id'] as String;
    }
    for (final h in bHistory) {
      final newFilmId = filmIdMap[h['film_id'] as String?];
      if (newFilmId == null) continue;
      final key = '$newFilmId|${h['watched_at']}'
          '|${h['season_number']}|${h['episode_number']}';
      final newId = newHistByKey[key];
      if (newId != null) historyIdMap[h['id'] as String] = newId;
    }

    // --- collection (history_id remappé via historyIdMap) ---
    int cntCollection = 0;
    for (final chunk in _chunks(bCollection, 200)) {
      final rows = chunk
          .where((c) => filmIdMap.containsKey(c['film_id']))
          .map((c) {
            final r = Map<String, dynamic>.from(c)..remove('id');
            r['film_id'] = filmIdMap[r['film_id']];
            r['user_id'] = _uid;
            final oldHistId = c['history_id'] as String?;
            r['history_id'] =
                oldHistId != null ? historyIdMap[oldHistId] : null;
            return r;
          })
          .toList();
      if (rows.isEmpty) continue;
      await _client.from('collection').insert(rows);
      cntCollection += rows.length;
    }

    // --- wishlist ---
    int cntWishlist = 0;
    for (final chunk in _chunks(bWishlist, 200)) {
      final rows = chunk
          .where((w) => filmIdMap.containsKey(w['film_id']))
          .map((w) {
            final r = Map<String, dynamic>.from(w)..remove('id');
            r['film_id'] = filmIdMap[r['film_id']];
            r['user_id'] = _uid;
            return r;
          })
          .toList();
      if (rows.isEmpty) continue;
      await _client.from('wishlist').insert(rows);
      cntWishlist += rows.length;
    }

    // --- favorites (clé naturelle : person_id → upsert) ---
    int cntFavorites = 0;
    for (final chunk in _chunks(bFavorites, 200)) {
      final rows = chunk.map((f) {
        final r = Map<String, dynamic>.from(f)..remove('id');
        r['user_id'] = _uid;
        return r;
      }).toList();
      await _client
          .from('favorites')
          .upsert(rows, onConflict: 'user_id,person_id');
      cntFavorites += rows.length;
    }

    return BackupStats(
      films: filmIdMap.length,
      seasons: cntSeasons,
      history: cntHistory,
      collection: cntCollection,
      wishlist: cntWishlist,
      favorites: cntFavorites,
    );
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(supabaseClientProvider));
});
