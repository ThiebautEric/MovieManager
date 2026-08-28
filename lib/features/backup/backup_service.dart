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
  /// La restauration est ATOMIQUE : la fonction Postgres `restore_backup`
  /// purge, remappe les UUID et réinsère les 6 tables dans une seule
  /// transaction. En cas de coupure, aucun état partiel n'est laissé.
  Future<BackupStats> importZip(Uint8List zipBytes) async {
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

    // Validation locale avant tout envoi : refuse un fichier vide ou invalide.
    if (bFilms.isEmpty && bHistory.isEmpty && bCollection.isEmpty &&
        bWishlist.isEmpty && bFavorites.isEmpty) {
      throw const FormatException('La sauvegarde ne contient aucune donnée.');
    }
    if (bFilms.isNotEmpty) {
      final f = bFilms.first;
      if (f['tmdb_id'] == null || f['media_type'] == null || f['id'] == null) {
        throw const FormatException('Format de sauvegarde invalide (films).');
      }
    }
    if (bHistory.isNotEmpty) {
      final h = bHistory.first;
      if (h['film_id'] == null || h['watched_at'] == null || h['id'] == null) {
        throw const FormatException('Format de sauvegarde invalide (historique).');
      }
    }

    // Restauration atomique côté serveur (transaction unique).
    final result = await _client.rpc('restore_backup', params: {
      'payload': {
        'films': bFilms,
        'film_seasons': bSeasons,
        'history': bHistory,
        'collection': bCollection,
        'wishlist': bWishlist,
        'favorites': bFavorites,
      },
    });

    final stats = (result as Map).cast<String, dynamic>();
    int n(String k) => (stats[k] as num?)?.toInt() ?? 0;
    return BackupStats(
      films: n('films'),
      seasons: n('seasons'),
      history: n('history'),
      collection: n('collection'),
      wishlist: n('wishlist'),
      favorites: n('favorites'),
    );
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(supabaseClientProvider));
});
