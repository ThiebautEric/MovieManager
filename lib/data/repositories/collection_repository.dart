import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/supabase/view_as.dart';
import '../models/collection_entry.dart';
import '../models/film.dart';
import '../models/film_season.dart';
import '../models/history_entry.dart';
import '../models/wishlist_entry.dart';

/// Contrat commun aux deux backends (cloud Supabase / local appareil).
///
/// Modèle normalisé : `films` (catalogue) + `collection` (possessions) +
/// `history` (visionnages) + `film_seasons` (saisons). `collection` et
/// `history` sont TOTALEMENT indépendantes : aucune suppression de l'une
/// n'affecte l'autre. Seule suppression automatique : un film qui n'est plus
/// référencé ni en collection ni en historique est retiré du catalogue.
abstract class LibraryRepository {
  Stream<List<CollectionView>> watchCollection();
  Stream<List<HistoryView>> watchHistory();
  Stream<List<WishlistView>> watchWishlist();

  Future<void> addToCollection(
    Film film, {
    FilmSeason? season,
    int? episodeNumber,
    String? historyId,
    required Medium medium,
    DateTime? addedAt,
  });

  Future<void> addToHistory(
    Film film, {
    FilmSeason? season,
    int? episodeNumber,
    String? episodeName,
    int? episodeRuntime,
    required DateTime watchedAt,
    double? rating,
    String? comment,
  });

  Future<void> updateHistory(
    String id, {
    required DateTime watchedAt,
    double? rating,
    String? comment,
  });

  /// Répare les métadonnées d'épisode d'un visionnage (nom générique stocké
  /// avant le repli en-US, durée absente…). Silencieux en lecture seule.
  Future<void> updateHistoryEpisodeMeta(
    String id, {
    String? episodeName,
    int? episodeRuntime,
  });

  /// Pense-bête : titres/saisons à voir ou à acheter plus tard.
  Future<void> addToWishlist(Film film, {FilmSeason? season});
  Future<void> removeFromWishlist(String id);

  /// Suppression par l'utilisateur uniquement (l'UI confirme).
  Future<void> removeFromCollection(String id);
  Future<void> removeFromHistory(String id);

  /// Met à jour les métadonnées d'un film DÉJÀ présent dans la bibliothèque
  /// (pays, casting, etc.) à partir d'une fiche TMDB fraîche. NE CRÉE PAS de
  /// film s'il n'est pas déjà référencé. Sert au « backfill » des anciennes
  /// entrées à l'ouverture de leur fiche.
  Future<void> backfillFilm(Film film);

  /// Stocke la somme exacte des runtimes d'épisodes dans film_seasons.
  /// N'est appelé que si TOUS les épisodes TMDB ont un runtime connu.
  Future<void> backfillSeasonRuntime(
    String filmId,
    int seasonNumber,
    int runtimeMinutes,
  );

  /// Resynchronise avec la source de vérité (autres appareils).
  Future<void> refresh();

  void dispose();
}

/// Journalisation TEMPORAIRE des durées de démarrage (diagnostic de la lenteur
/// croissante du chargement initial). Passer à `false` pour couper tous les logs.
const bool _perfLog = false;
void _plog(String msg) {
  if (_perfLog) debugPrint('[perf][repo] $msg');
}

String _seasonKey(String filmId, int seasonNumber) => '$filmId:$seasonNumber';

/// Fusionne une fiche fraîche TMDB [f] dans le film existant [e] : on garde
/// l'identité (id/titre/affiche/année) et on complète avec les métadonnées
/// fraîches (pays, casting, genres, durée, synopsis, titre original).
Film _mergeFilm(Film e, Film f) => Film(
      id: e.id,
      tmdbId: e.tmdbId,
      mediaType: e.mediaType,
      title: e.title,
      posterPath: f.posterPath ?? e.posterPath,
      releaseYear: e.releaseYear,
      originalTitle: f.originalTitle ?? e.originalTitle,
      runtime: f.runtime ?? e.runtime,
      overview: (f.overview?.isNotEmpty ?? false) ? f.overview : e.overview,
      originCountry: f.originCountry ?? e.originCountry,
      genres: f.genres.isNotEmpty ? f.genres : e.genres,
      castIds: f.castIds.isNotEmpty ? f.castIds : e.castIds,
      collectionId: f.collectionId ?? e.collectionId,
    );

bool _intSetEq(List<int> a, List<int> b) {
  final sa = a.toSet(), sb = b.toSet();
  return sa.length == sb.length && sa.containsAll(sb);
}

/// Vrai si les métadonnées « enrichissables » sont identiques (rien à réécrire).
bool _sameMeta(Film a, Film b) =>
    a.posterPath == b.posterPath &&
    a.originCountry == b.originCountry &&
    a.runtime == b.runtime &&
    a.overview == b.overview &&
    a.originalTitle == b.originalTitle &&
    a.collectionId == b.collectionId &&
    _intSetEq(a.genres, b.genres) &&
    _intSetEq(a.castIds, b.castIds);

// ===========================================================================
// Backend cloud : 5 tables Supabase (films, film_seasons, collection, history,
// wishlist) écoutées EN TEMPS RÉEL via .stream() et jointes en mémoire en vues
// composites (CollectionView / HistoryView / WishlistView). L'instantané local
// assure un premier rendu immédiat ; les flux prennent ensuite le relais et
// maintiennent les données à jour en direct sur tous les appareils.
// ===========================================================================
class SupabaseLibraryRepository implements LibraryRepository {
  SupabaseLibraryRepository(this._client, this._prefs, {this._targetUserId});

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  /// Mode « consultation admin » : lit les données de cet utilisateur au lieu
  /// de celles du compte connecté. Les politiques RLS n'accordent que SELECT,
  /// donc le repository devient lecture seule.
  final String? _targetUserId;

  bool get readOnly => _targetUserId != null;

  void _assertWritable() {
    if (readOnly) {
      throw StateError('Lecture seule : consultation admin.');
    }
  }

  // Caches sources (chargés par pagination, voir _loadAll).
  Map<String, Film> _filmsById = {};
  Map<String, Film> _filmsByKey = {};
  List<FilmSeason> _seasons = const [];
  List<CollectionEntry> _collection = const [];
  List<HistoryEntry> _history = const [];
  List<WishlistEntry> _wishlist = const [];

  // Canal temps réel unique (un seul websocket, bindings postgres_changes par
  // table) : les modifications (le tien, un autre appareil, le trigger GC) sont
  // appliquées en delta au cache local et reflétées en direct.
  RealtimeChannel? _channel;
  // Vrai après le premier `subscribed` : tout `subscribed` suivant est un
  // rejoin (websocket coupé puis rétabli) → rattrapage REST (voir plus bas).
  bool _subscribedOnce = false;
  // _loadAll en cours, partagé pour ne pas lancer deux rechargements complets
  // en parallèle (resume + rejoin realtime arrivent quasi en même temps).
  Future<void>? _loading;

  StreamController<List<CollectionView>>? _collectionCtrl;
  StreamController<List<HistoryView>>? _historyCtrl;
  StreamController<List<WishlistView>>? _wishlistCtrl;
  // Dernières vues émises, rejouées aux nouveaux abonnés (flux broadcast).
  List<CollectionView> _lastColl = const [];
  List<HistoryView> _lastHist = const [];
  List<WishlistView> _lastWish = const [];
  bool _loaded = false;
  bool _emitted = false; // au moins une émission faite (rejouable aux abonnés)

  String get _userId {
    if (_targetUserId != null) return _targetUserId;
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Aucun utilisateur connecté.');
    return id;
  }

  void _ensureLoaded() {
    _collectionCtrl ??= StreamController<List<CollectionView>>.broadcast();
    _historyCtrl ??= StreamController<List<HistoryView>>.broadcast();
    _wishlistCtrl ??= StreamController<List<WishlistView>>.broadcast();
    if (!_loaded) {
      _loaded = true;
      if (readOnly) {
        // Consultation admin (lecture seule, données d'un tiers) : un seul select,
        // sans temps réel (fragile avec les claims JWT) ni instantané local.
        _loadAll();
      } else {
        // Rendu « local-first », en 3 temps :
        //   1. instantané local (synchrone) → premier rendu immédiat, hors-ligne ;
        //   2. _loadAll() (REST) → socle FIABLE, rafraîchit depuis Supabase même
        //      si le temps réel est indisponible (jamais pire que l'original) ;
        //   3. temps réel (best-effort) → mises à jour EN DIRECT ensuite, ce qui
        //      supprime la péremption au démarrage et le besoin de refresh manuel.
        _loadSnapshot();
        _loadAll();
        _subscribeRealtime();
      }
    }
  }

  // --- Instantané local (cache hors-ligne) ---------------------------------

  static const _snapshotPrefix = 'cloud_snapshot_v1_';

  /// Clé de l'instantané, isolée par utilisateur (jamais de fuite entre comptes).
  String get _snapshotKey => '$_snapshotPrefix$_userId';

  /// Applique un lot de lignes brutes (issues du réseau OU de l'instantané) aux
  /// caches et reconstruit les vues. Chemin unique partagé par les deux sources.
  void _applyRows(
    List<Map<String, dynamic>> films,
    List<Map<String, dynamic>> seasons,
    List<Map<String, dynamic>> coll,
    List<Map<String, dynamic>> hist,
    List<Map<String, dynamic>> wish, {
    String tag = '',
  }) {
    final parseSw = Stopwatch()..start();
    final fl = films.map(Film.fromJson).toList();
    _filmsById = {for (final f in fl) f.id!: f};
    _filmsByKey = {for (final f in fl) f.mediaKey: f};
    _seasons = seasons.map(FilmSeason.fromJson).toList();
    _collection = coll.map(CollectionEntry.fromJson).toList();
    _history = hist.map(HistoryEntry.fromJson).toList();
    _wishlist = wish.map(WishlistEntry.fromJson).toList();
    parseSw.stop();
    final rebuildSw = Stopwatch()..start();
    _rebuild();
    rebuildSw.stop();
    _plog('applyRows[$tag]: parse ${parseSw.elapsedMilliseconds} ms, '
        'rebuild ${rebuildSw.elapsedMilliseconds} ms '
        '(films=${fl.length}, seasons=${_seasons.length}, '
        'coll=${_collection.length}, hist=${_history.length}, '
        'wish=${_wishlist.length})');
  }

  /// Affiche l'instantané local s'il existe. Jamais en consultation (view-as) :
  /// on ne cache et n'affiche que ses propres données.
  void _loadSnapshot() {
    if (readOnly) return;
    try {
      final raw = _prefs.getString(_snapshotKey);
      if (raw == null) {
        _plog('snapshot: absent');
        return;
      }
      final decodeSw = Stopwatch()..start();
      final snap = jsonDecode(raw) as Map<String, dynamic>;
      decodeSw.stop();
      _plog('snapshot: ${(raw.length / 1024).toStringAsFixed(0)} Ko, '
          'jsonDecode ${decodeSw.elapsedMilliseconds} ms');
      List<Map<String, dynamic>> rows(String k) =>
          (snap[k] as List).cast<Map<String, dynamic>>();
      _applyRows(rows('films'), rows('seasons'), rows('collection'),
          rows('history'), rows('wishlist'),
          tag: 'snapshot');
    } catch (_) {
      // Instantané absent/corrompu : on ignore, le réseau prendra le relais.
    }
  }

  /// Écrit l'instantané après un chargement réseau réussi (best-effort).
  Future<void> _saveSnapshot(
    List<Map<String, dynamic>> films,
    List<Map<String, dynamic>> seasons,
    List<Map<String, dynamic>> coll,
    List<Map<String, dynamic>> hist,
    List<Map<String, dynamic>> wish,
  ) async {
    if (readOnly) return; // ne jamais cacher les données consultées d'un tiers
    var size = 0;
    try {
      final encodeSw = Stopwatch()..start();
      final encoded = jsonEncode({
        'films': films,
        'seasons': seasons,
        'collection': coll,
        'history': hist,
        'wishlist': wish,
      });
      encodeSw.stop();
      size = encoded.length;
      final writeSw = Stopwatch()..start();
      final ok = await _prefs.setString(_snapshotKey, encoded);
      writeSw.stop();
      if (!ok) throw StateError('setString a renvoyé false');
      _plog('saveSnapshot: jsonEncode ${encodeSw.elapsedMilliseconds} ms, '
          'setString ${writeSw.elapsedMilliseconds} ms, '
          '${(size / 1024).toStringAsFixed(0)} Ko');
    } catch (e) {
      // Best-effort, mais jamais silencieux : un échec ici fige l'instantané.
      debugPrint('[repo] saveSnapshot échoué '
          '(${(size / 1024).toStringAsFixed(0)} Ko) : $e');
    }
  }

  /// Charge une table en entier en paginant (PostgREST plafonne à 1000 lignes
  /// par requête ; on enchaîne les pages jusqu'à épuisement).
  Future<List<Map<String, dynamic>>> _selectAll(String table) async {
    const pageSize = 1000;
    final out = <Map<String, dynamic>>[];
    var from = 0;
    var pages = 0;
    final sw = Stopwatch()..start();
    while (true) {
      final rows = await _client
          .from(table)
          .select()
          .eq('user_id', _userId)
          .order('id')
          .range(from, from + pageSize - 1);
      final list = (rows as List).cast<Map<String, dynamic>>();
      out.addAll(list);
      pages++;
      if (list.length < pageSize) break;
      from += pageSize;
    }
    sw.stop();
    _plog('select $table: ${sw.elapsedMilliseconds} ms '
        '(${out.length} lignes, $pages page(s))');
    return out;
  }

  Future<void> _loadAll() =>
      _loading ??= _doLoadAll().whenComplete(() => _loading = null);

  Future<void> _doLoadAll() async {
    final totalSw = Stopwatch()..start();
    try {
      // Charge les 5 tables en parallèle — gain ~200 ms vs séquentiel.
      final netSw = Stopwatch()..start();
      final results = await Future.wait([
        _selectAll('films'),
        _selectAll('film_seasons'),
        _selectAll('collection'),
        _selectAll('history'),
        // Tolère l'absence de la table (migration SQL pas encore exécutée).
        _selectAll('wishlist').catchError((_) => <Map<String, dynamic>>[]),
      ]);
      netSw.stop();
      _plog('réseau _loadAll (Future.wait des 5 tables): '
          '${netSw.elapsedMilliseconds} ms');
      final films = results[0];
      final seasons = results[1];
      final coll = results[2];
      final hist = results[3];
      final wish = results[4];
      _applyRows(films, seasons, coll, hist, wish, tag: 'réseau');
      _saveSnapshot(films, seasons, coll, hist, wish);
      totalSw.stop();
      _plog('_loadAll total (réseau + parse + rebuild + save): '
          '${totalSw.elapsedMilliseconds} ms');
    } catch (e, st) {
      // Si un instantané (ou un chargement précédent) est déjà affiché, une
      // panne réseau ne doit pas casser l'écran : on garde le cache local et on
      // réessaiera à la prochaine ouverture. Sinon, on propage l'erreur.
      if (_emitted) return;
      _loaded = false;
      _collectionCtrl?.addError(e, st);
      _historyCtrl?.addError(e, st);
      _wishlistCtrl?.addError(e, st);
    }
  }

  // Tables suivies en temps réel (ordre indifférent).
  static const _realtimeTables = [
    'films',
    'film_seasons',
    'collection',
    'history',
    'wishlist',
  ];

  /// Ouvre UN canal realtime et y attache, par table :
  ///   - un binding INSERT/UPDATE filtré par user_id (ne reçoit que mes lignes) ;
  ///   - un binding DELETE NON filtré : sous RLS, l'« ancienne » ligne d'un DELETE
  ///     ne contient que la clé primaire, donc un filtre user_id ne matcherait
  ///     jamais. Non filtré, on reçoit tous les DELETE (clé primaire seule) ;
  ///     retirer un id absent du cache est un no-op → sans risque et correct.
  ///
  /// Best-effort : si le temps réel est indisponible (timeout, hors-ligne), on
  /// log et on ignore — le socle `_loadAll()` (REST) a déjà fourni les données.
  void _subscribeRealtime() {
    final String uid;
    try {
      uid = _userId;
    } catch (_) {
      return; // pas connecté : rien à faire
    }
    final channel = _client.channel('library_$uid');
    for (final table in _realtimeTables) {
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
            callback: (p) => _onRealtimeChange(table, p),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
            callback: (p) => _onRealtimeChange(table, p),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: table,
            callback: (p) => _onRealtimeChange(table, p),
          );
    }
    channel.subscribe((status, [error]) {
      _plog('realtime: $status${error != null ? ' ($error)' : ''}');
      if (status != RealtimeSubscribeStatus.subscribed) return;
      // Supabase ne rejoue pas les événements manqués pendant une coupure. Or
      // sur mobile, supabase_flutter FERME le websocket dès que l'app passe en
      // arrière-plan et le rouvre au retour : tout ce qui a changé entre-temps
      // (ex. depuis le web) serait perdu. Chaque rejoin déclenche donc un
      // rechargement REST complet pour rattraper le trou.
      if (_subscribedOnce) {
        _loadAll();
      } else {
        _subscribedOnce = true;
      }
    });
    _channel = channel;
  }

  /// Applique un changement temps réel au cache de la table concernée, puis
  /// reconstruit les vues. Tolère toute ligne illisible sans casser l'app.
  void _onRealtimeChange(String table, PostgresChangePayload p) {
    try {
      final isDelete = p.eventType == PostgresChangeEvent.delete;
      final row = isDelete ? p.oldRecord : p.newRecord;
      final id = row['id'] as String?;
      if (id == null) return;
      switch (table) {
        case 'films':
          if (isDelete) {
            final old = _filmsById.remove(id);
            if (old != null) _filmsByKey.remove(old.mediaKey);
          } else {
            final f = Film.fromJson(p.newRecord);
            final old = _filmsById[id];
            if (old != null) _filmsByKey.remove(old.mediaKey);
            if (f.id != null) {
              _filmsById[f.id!] = f;
              _filmsByKey[f.mediaKey] = f;
            }
          }
        case 'film_seasons':
          _seasons = isDelete
              ? _seasons.where((e) => e.id != id).toList()
              : [..._seasons.where((e) => e.id != id), FilmSeason.fromJson(p.newRecord)];
        case 'collection':
          _collection = isDelete
              ? _collection.where((e) => e.id != id).toList()
              : [..._collection.where((e) => e.id != id), CollectionEntry.fromJson(p.newRecord)];
        case 'history':
          _history = isDelete
              ? _history.where((e) => e.id != id).toList()
              : [..._history.where((e) => e.id != id), HistoryEntry.fromJson(p.newRecord)];
        case 'wishlist':
          _wishlist = isDelete
              ? _wishlist.where((e) => e.id != id).toList()
              : [..._wishlist.where((e) => e.id != id), WishlistEntry.fromJson(p.newRecord)];
        default:
          return;
      }
      _rebuild();
    } catch (e) {
      _plog('realtime $table: apply error $e');
    }
  }

  void _rebuild() {
    final seasonByKey = <String, FilmSeason>{
      for (final s in _seasons)
        if (s.filmId != null) _seasonKey(s.filmId!, s.seasonNumber): s,
    };
    final historyById = <String, HistoryEntry>{
      for (final h in _history) if (h.id != null) h.id!: h,
    };

    // Dédoublonnage par id : évite tout doublon transitoire entre la mise à
    // jour optimiste et l'écho temps réel d'un insert (corrigé sinon au reload).
    final seenColl = <String>{};
    final coll = <CollectionView>[];
    for (final e in _collection) {
      if (e.id != null && !seenColl.add(e.id!)) continue;
      final film = _filmsById[e.filmId];
      if (film == null) continue; // film pas encore reçu : ignoré transitoirement
      coll.add(CollectionView(
        entry: e,
        film: film,
        season: e.seasonNumber == null
            ? null
            : seasonByKey[_seasonKey(e.filmId, e.seasonNumber!)],
        linkedHistory: e.historyId != null ? historyById[e.historyId] : null,
      ));
    }
    coll.sort((a, b) {
      final t = a.film.title.toLowerCase().compareTo(b.film.title.toLowerCase());
      if (t != 0) return t;
      return (a.seasonNumber ?? -1).compareTo(b.seasonNumber ?? -1);
    });

    final seenHist = <String>{};
    final hist = <HistoryView>[];
    for (final e in _history) {
      if (e.id != null && !seenHist.add(e.id!)) continue;
      final film = _filmsById[e.filmId];
      if (film == null) continue;
      hist.add(HistoryView(
        entry: e,
        film: film,
        season: e.seasonNumber == null
            ? null
            : seasonByKey[_seasonKey(e.filmId, e.seasonNumber!)],
      ));
    }
    hist.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));

    final seenWish = <String>{};
    final wish = <WishlistView>[];
    for (final e in _wishlist) {
      if (e.id != null && !seenWish.add(e.id!)) continue;
      final film = _filmsById[e.filmId];
      if (film == null) continue;
      wish.add(WishlistView(
        entry: e,
        film: film,
        season: e.seasonNumber == null
            ? null
            : seasonByKey[_seasonKey(e.filmId, e.seasonNumber!)],
      ));
    }
    // Du plus récemment ajouté au plus ancien.
    wish.sort((a, b) => (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)));

    _lastColl = List.unmodifiable(coll);
    _lastHist = List.unmodifiable(hist);
    _lastWish = List.unmodifiable(wish);
    _emitted = true;
    _collectionCtrl?.add(_lastColl);
    _historyCtrl?.add(_lastHist);
    _wishlistCtrl?.add(_lastWish);
  }

  @override
  Stream<List<CollectionView>> watchCollection() async* {
    _ensureLoaded();
    if (_emitted) yield _lastColl;
    yield* _collectionCtrl!.stream;
  }

  @override
  Stream<List<HistoryView>> watchHistory() async* {
    _ensureLoaded();
    if (_emitted) yield _lastHist;
    yield* _historyCtrl!.stream;
  }

  @override
  Stream<List<WishlistView>> watchWishlist() async* {
    _ensureLoaded();
    if (_emitted) yield _lastWish;
    yield* _wishlistCtrl!.stream;
  }

  /// Upsert le film (catalogue) et renvoie la version persistée (avec id).
  Future<Film> _upsertFilm(Film film) async {
    final row = await _client
        .from('films')
        .upsert({...film.toUpsertJson(), 'user_id': _userId},
            onConflict: 'user_id,tmdb_id,media_type')
        .select()
        .single();
    final saved = Film.fromJson(row);
    _filmsById[saved.id!] = saved;
    _filmsByKey[saved.mediaKey] = saved;
    return saved;
  }

  /// Upsert la saison (catalogue) pour un film donné.
  Future<void> _upsertSeason(Film film, FilmSeason season) async {
    final payload = {
      ...season.toUpsertJson(),
      'user_id': _userId,
      'film_id': film.id,
    };
    final row = await _client
        .from('film_seasons')
        .upsert(payload, onConflict: 'film_id,season_number')
        .select()
        .single();
    final saved = FilmSeason.fromJson(row);
    _seasons = [
      ..._seasons.where(
          (x) => !(x.filmId == saved.filmId && x.seasonNumber == saved.seasonNumber)),
      saved,
    ];
  }

  @override
  Future<void> addToCollection(
    Film film, {
    FilmSeason? season,
    int? episodeNumber,
    String? historyId,
    required Medium medium,
    DateTime? addedAt,
  }) async {
    _assertWritable();
    final saved = await _upsertFilm(film);
    if (season != null) await _upsertSeason(saved, season);

    // Dédup : par entrée historique (saisie rapide) ou par (film, saison, épisode, support).
    final already = historyId != null
        ? _collection.any((e) => e.historyId == historyId && e.medium == medium)
        : _collection.any((e) =>
            e.filmId == saved.id &&
            e.seasonNumber == season?.seasonNumber &&
            e.episodeNumber == episodeNumber &&
            e.historyId == null &&
            e.medium == medium);
    if (already) return;

    final entry = CollectionEntry(
      filmId: saved.id!,
      seasonNumber: season?.seasonNumber,
      episodeNumber: episodeNumber,
      historyId: historyId,
      medium: medium,
      addedAt: addedAt ?? DateTime.now(),
    );
    final row = await _client
        .from('collection')
        .insert({...entry.toUpsertJson(), 'user_id': _userId})
        .select()
        .single();
    final saved2 = CollectionEntry.fromJson(row);
    _collection = [
      ..._collection.where((e) => e.id != saved2.id),
      saved2,
    ];
    _rebuild();
  }

  @override
  Future<void> backfillSeasonRuntime(
    String filmId,
    int seasonNumber,
    int runtimeMinutes,
  ) async {
    if (readOnly) return;
    await _client
        .from('film_seasons')
        .update({'runtime_minutes': runtimeMinutes})
        .eq('film_id', filmId)
        .eq('season_number', seasonNumber)
        .eq('user_id', _userId);
    _seasons = [
      for (final s in _seasons)
        if (s.filmId == filmId && s.seasonNumber == seasonNumber)
          FilmSeason(
            id: s.id,
            filmId: s.filmId,
            seasonNumber: s.seasonNumber,
            name: s.name,
            posterPath: s.posterPath,
            airYear: s.airYear,
            episodeCount: s.episodeCount,
            runtimeMinutes: runtimeMinutes,
          )
        else
          s,
    ];
    _rebuild();
  }

  @override
  Future<void> addToHistory(
    Film film, {
    FilmSeason? season,
    int? episodeNumber,
    String? episodeName,
    int? episodeRuntime,
    required DateTime watchedAt,
    double? rating,
    String? comment,
  }) async {
    _assertWritable();
    final saved = await _upsertFilm(film);
    if (season != null) await _upsertSeason(saved, season);

    final entry = HistoryEntry(
      filmId: saved.id!,
      seasonNumber: season?.seasonNumber,
      episodeNumber: episodeNumber,
      episodeName: episodeName,
      episodeRuntime: episodeRuntime,
      watchedAt: watchedAt,
      rating: rating,
      comment: comment,
    );
    final row = await _client
        .from('history')
        .insert({...entry.toUpsertJson(), 'user_id': _userId})
        .select()
        .single();
    final saved2 = HistoryEntry.fromJson(row);
    _history = [
      ..._history.where((e) => e.id != saved2.id),
      saved2,
    ];
    _rebuild();
  }

  @override
  Future<void> addToWishlist(Film film, {FilmSeason? season}) async {
    _assertWritable();
    final saved = await _upsertFilm(film);
    if (season != null) await _upsertSeason(saved, season);

    final already = _wishlist.any((e) =>
        e.filmId == saved.id && e.seasonNumber == season?.seasonNumber);
    if (already) return;

    final entry = WishlistEntry(
      filmId: saved.id!,
      seasonNumber: season?.seasonNumber,
      addedAt: DateTime.now(),
    );
    final row = await _client
        .from('wishlist')
        .insert({...entry.toUpsertJson(), 'user_id': _userId})
        .select()
        .single();
    final saved2 = WishlistEntry.fromJson(row);
    _wishlist = [
      ..._wishlist.where((e) => e.id != saved2.id),
      saved2,
    ];
    _rebuild();
  }

  @override
  Future<void> removeFromWishlist(String id) async {
    _assertWritable();
    final filmId = _filmIdOfWishlist(id);
    await _client.from('wishlist').delete().eq('id', id).eq('user_id', _userId);
    _wishlist = _wishlist.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilmLocally(filmId);
    _rebuild();
  }

  String? _filmIdOfWishlist(String id) {
    for (final e in _wishlist) {
      if (e.id == id) return e.filmId;
    }
    return null;
  }

  @override
  Future<void> updateHistory(
    String id, {
    required DateTime watchedAt,
    double? rating,
    String? comment,
  }) async {
    _assertWritable();
    await _client.from('history').update({
      'watched_at': watchedAt.toUtc().toIso8601String(),
      'rating': rating,
      'comment': comment,
    }).eq('id', id).eq('user_id', _userId);
    _history = _history
        .map((e) => e.id == id
            ? HistoryEntry(
                id: e.id,
                filmId: e.filmId,
                seasonNumber: e.seasonNumber,
                episodeNumber: e.episodeNumber,
                episodeName: e.episodeName,
                episodeRuntime: e.episodeRuntime,
                watchedAt: watchedAt,
                rating: rating,
                comment: comment,
              )
            : e)
        .toList();
    _rebuild();
  }

  @override
  Future<void> updateHistoryEpisodeMeta(
    String id, {
    String? episodeName,
    int? episodeRuntime,
  }) async {
    if (readOnly) return; // réparation silencieuse, jamais en consultation
    if (episodeName == null && episodeRuntime == null) return;
    await _client.from('history').update({
      if (episodeName != null) 'episode_name': episodeName,
      if (episodeRuntime != null) 'episode_runtime': episodeRuntime,
    }).eq('id', id).eq('user_id', _userId);
    _history = _history
        .map((e) => e.id == id
            ? HistoryEntry(
                id: e.id,
                filmId: e.filmId,
                seasonNumber: e.seasonNumber,
                episodeNumber: e.episodeNumber,
                episodeName: episodeName ?? e.episodeName,
                episodeRuntime: episodeRuntime ?? e.episodeRuntime,
                watchedAt: e.watchedAt,
                rating: e.rating,
                comment: e.comment,
              )
            : e)
        .toList();
    _rebuild();
  }

  @override
  Future<void> removeFromCollection(String id) async {
    _assertWritable();
    final filmId = _filmIdOfCollection(id);
    await _client.from('collection').delete().eq('id', id).eq('user_id', _userId);
    _collection = _collection.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilmLocally(filmId);
    _rebuild();
  }

  @override
  Future<void> removeFromHistory(String id) async {
    _assertWritable();
    final filmId = _filmIdOfHistory(id);
    await _client.from('history').delete().eq('id', id).eq('user_id', _userId);
    _history = _history.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilmLocally(filmId);
    _rebuild();
  }

  String? _filmIdOfCollection(String id) {
    for (final e in _collection) {
      if (e.id == id) return e.filmId;
    }
    return null;
  }

  String? _filmIdOfHistory(String id) {
    for (final e in _history) {
      if (e.id == id) return e.filmId;
    }
    return null;
  }

  /// Reflète localement le GC serveur (trigger) : retire du cache un film qui
  /// n'est plus référencé, pour une UI immédiatement cohérente.
  void _gcFilmLocally(String filmId) {
    final stillRef = _collection.any((e) => e.filmId == filmId) ||
        _history.any((e) => e.filmId == filmId) ||
        _wishlist.any((e) => e.filmId == filmId);
    if (stillRef) return;
    final film = _filmsById.remove(filmId);
    if (film != null) _filmsByKey.remove(film.mediaKey);
    _seasons = _seasons.where((s) => s.filmId != filmId).toList();
  }

  @override
  Future<void> refresh() async {
    _ensureLoaded();
    if (readOnly) {
      // Consultation admin : pas de flux, on recharge en one-shot.
      await _loadAll();
      return;
    }
    // Le temps réel maintient déjà les données à jour pendant la session ; un
    // refresh manuel force une re-synchronisation complète via REST (rattrape
    // d'éventuels changements survenus hors-ligne / temps réel indisponible).
    await _loadAll();
  }

  @override
  Future<void> backfillFilm(Film fresh) async {
    // No-op silencieux (pas de throw) : HomeShell le déclenche automatiquement
    // au démarrage, y compris pendant une consultation admin.
    if (readOnly) return;
    final existing = _filmsByKey[fresh.mediaKey];
    if (existing == null) return; // pas dans la bibliothèque → on ne crée rien
    final merged = _mergeFilm(existing, fresh);
    if (_sameMeta(existing, merged)) return; // rien de neuf à écrire
    await _client.from('films').update({
      'poster_path': merged.posterPath,
      'origin_country': merged.originCountry,
      'cast_ids': merged.castIds,
      'runtime': merged.runtime,
      'overview': merged.overview,
      'original_title': merged.originalTitle,
      'genres': merged.genres,
    }).eq('id', existing.id!).eq('user_id', _userId);
    _filmsById[existing.id!] = merged;
    _filmsByKey[merged.mediaKey] = merged;
    _rebuild();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      _channel = null;
      _client.removeChannel(channel);
    }
    _collectionCtrl?.close();
    _historyCtrl?.close();
    _wishlistCtrl?.close();
  }
}

// ===========================================================================
// Backend local : mêmes structures persistées dans shared_preferences (sans
// compte ni synchro). Le GC des films orphelins est fait côté application.
// ===========================================================================
class LocalLibraryRepository implements LibraryRepository {
  LocalLibraryRepository(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _filmsKey = 'lib_films_v1';
  static const _seasonsKey = 'lib_seasons_v1';
  static const _collectionKey = 'lib_collection_v1';
  static const _historyKey = 'lib_history_v1';
  static const _wishlistKey = 'lib_wishlist_v1';

  final _collectionCtrl = StreamController<List<CollectionView>>.broadcast();
  final _historyCtrl = StreamController<List<HistoryView>>.broadcast();
  final _wishlistCtrl = StreamController<List<WishlistView>>.broadcast();

  // Dernières valeurs émises — permet de les rejouer immédiatement pour les
  // nouveaux abonnés sans perdre le premier événement sur un broadcast stream.
  List<CollectionView> _lastColl = const [];
  List<HistoryView> _lastHist = const [];
  List<WishlistView> _lastWish = const [];

  Map<String, Film> _filmsById = {};
  Map<String, Film> _filmsByKey = {};
  List<FilmSeason> _seasons = [];
  List<CollectionEntry> _collection = [];
  List<HistoryEntry> _history = [];
  List<WishlistEntry> _wishlist = [];
  int _seq = 0;

  List<T> _decode<T>(String key, T Function(Map<String, dynamic>) f) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => f(e as Map<String, dynamic>))
        .toList();
  }

  void _load() {
    final films = _decode(_filmsKey, Film.fromJson);
    _filmsById = {for (final f in films) if (f.id != null) f.id!: f};
    _filmsByKey = {for (final f in films) f.mediaKey: f};
    _seasons = _decode(_seasonsKey, FilmSeason.fromJson);
    _collection = _decode(_collectionKey, CollectionEntry.fromJson);
    _history = _decode(_historyKey, HistoryEntry.fromJson);
    _wishlist = _decode(_wishlistKey, WishlistEntry.fromJson);
  }

  Future<void> _persistFilms() =>
      _prefs.setString(_filmsKey,
          jsonEncode(_filmsById.values.map((e) => e.toFullJson()).toList()));

  Future<void> _persistSeasons() =>
      _prefs.setString(_seasonsKey,
          jsonEncode(_seasons.map((e) => e.toFullJson()).toList()));

  Future<void> _persistCollection() =>
      _prefs.setString(_collectionKey,
          jsonEncode(_collection.map((e) => e.toFullJson()).toList()));

  Future<void> _persistHistory() =>
      _prefs.setString(_historyKey,
          jsonEncode(_history.map((e) => e.toFullJson()).toList()));

  Future<void> _persistWishlist() =>
      _prefs.setString(_wishlistKey,
          jsonEncode(_wishlist.map((e) => e.toFullJson()).toList()));


  void _emit() {
    final seasonByKey = <String, FilmSeason>{
      for (final s in _seasons)
        if (s.filmId != null) _seasonKey(s.filmId!, s.seasonNumber): s,
    };
    final historyById = <String, HistoryEntry>{
      for (final h in _history) if (h.id != null) h.id!: h,
    };
    final coll = [
      for (final e in _collection)
        if (_filmsById[e.filmId] != null)
          CollectionView(
            entry: e,
            film: _filmsById[e.filmId]!,
            season: e.seasonNumber == null
                ? null
                : seasonByKey[_seasonKey(e.filmId, e.seasonNumber!)],
            linkedHistory: e.historyId != null ? historyById[e.historyId] : null,
          )
    ]..sort((a, b) {
        final t =
            a.film.title.toLowerCase().compareTo(b.film.title.toLowerCase());
        return t != 0 ? t : (a.seasonNumber ?? -1).compareTo(b.seasonNumber ?? -1);
      });
    final hist = [
      for (final e in _history)
        if (_filmsById[e.filmId] != null)
          HistoryView(
            entry: e,
            film: _filmsById[e.filmId]!,
            season: e.seasonNumber == null
                ? null
                : seasonByKey[_seasonKey(e.filmId, e.seasonNumber!)],
          )
    ]..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    final wish = [
      for (final e in _wishlist)
        if (_filmsById[e.filmId] != null)
          WishlistView(
            entry: e,
            film: _filmsById[e.filmId]!,
            season: e.seasonNumber == null
                ? null
                : seasonByKey[_seasonKey(e.filmId, e.seasonNumber!)],
          )
    ]..sort((a, b) =>
        (b.addedAt ?? DateTime(0)).compareTo(a.addedAt ?? DateTime(0)));
    _lastColl = List.unmodifiable(coll);
    _lastHist = List.unmodifiable(hist);
    _lastWish = List.unmodifiable(wish);
    _collectionCtrl.add(_lastColl);
    _historyCtrl.add(_lastHist);
    _wishlistCtrl.add(_lastWish);
  }

  @override
  Stream<List<CollectionView>> watchCollection() async* {
    _emit();
    yield _lastColl;
    yield* _collectionCtrl.stream;
  }

  @override
  Stream<List<HistoryView>> watchHistory() async* {
    _emit();
    yield _lastHist;
    yield* _historyCtrl.stream;
  }

  @override
  Stream<List<WishlistView>> watchWishlist() async* {
    _emit();
    yield _lastWish;
    yield* _wishlistCtrl.stream;
  }

  String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  Film _ensureFilm(Film film) {
    final existing = _filmsByKey[film.mediaKey];
    final id = existing?.id ?? film.mediaKey;
    final saved = Film(
      id: id,
      tmdbId: film.tmdbId,
      mediaType: film.mediaType,
      title: film.title,
      originalTitle: film.originalTitle,
      posterPath: film.posterPath,
      releaseYear: film.releaseYear,
      runtime: film.runtime,
      overview: film.overview,
      originCountry: film.originCountry,
      genres: film.genres,
      castIds: film.castIds,
      collectionId: film.collectionId ?? existing?.collectionId,
    );
    _filmsById[id] = saved;
    _filmsByKey[saved.mediaKey] = saved;
    return saved;
  }

  void _ensureSeason(Film film, FilmSeason season) {
    // Préserve les métadonnées déjà connues (durée/nb d'épisodes backfillés)
    // quand le nouvel objet saison ne les porte pas.
    FilmSeason? existing;
    for (final x in _seasons) {
      if (x.filmId == film.id && x.seasonNumber == season.seasonNumber) {
        existing = x;
        break;
      }
    }
    final saved = FilmSeason(
      id: '${film.id}#${season.seasonNumber}',
      filmId: film.id,
      seasonNumber: season.seasonNumber,
      name: season.name ?? existing?.name,
      posterPath: season.posterPath ?? existing?.posterPath,
      airYear: season.airYear ?? existing?.airYear,
      episodeCount: season.episodeCount ?? existing?.episodeCount,
      runtimeMinutes: season.runtimeMinutes ?? existing?.runtimeMinutes,
    );
    _seasons = [
      ..._seasons.where(
          (x) => !(x.filmId == saved.filmId && x.seasonNumber == saved.seasonNumber)),
      saved,
    ];
  }

  @override
  Future<void> addToCollection(
    Film film, {
    FilmSeason? season,
    int? episodeNumber,
    String? historyId,
    required Medium medium,
    DateTime? addedAt,
  }) async {
    final saved = _ensureFilm(film);
    if (season != null) _ensureSeason(saved, season);
    final already = historyId != null
        ? _collection.any((e) => e.historyId == historyId && e.medium == medium)
        : _collection.any((e) =>
            e.filmId == saved.id &&
            e.seasonNumber == season?.seasonNumber &&
            e.episodeNumber == episodeNumber &&
            e.historyId == null &&
            e.medium == medium);
    if (already) return;
    _collection = [
      ..._collection,
      CollectionEntry(
        id: _nextId(),
        filmId: saved.id!,
        seasonNumber: season?.seasonNumber,
        episodeNumber: episodeNumber,
        historyId: historyId,
        medium: medium,
        addedAt: addedAt ?? DateTime.now(),
      ),
    ];
    await Future.wait([_persistFilms(), _persistSeasons(), _persistCollection()]);
    _emit();
  }

  @override
  Future<void> backfillSeasonRuntime(
    String filmId,
    int seasonNumber,
    int runtimeMinutes,
  ) async {
    _seasons = [
      for (final s in _seasons)
        if (s.filmId == filmId && s.seasonNumber == seasonNumber)
          FilmSeason(
            id: s.id,
            filmId: s.filmId,
            seasonNumber: s.seasonNumber,
            name: s.name,
            posterPath: s.posterPath,
            airYear: s.airYear,
            episodeCount: s.episodeCount,
            runtimeMinutes: runtimeMinutes,
          )
        else
          s,
    ];
    await _persistSeasons();
    _emit();
  }



  @override
  Future<void> addToHistory(
    Film film, {
    FilmSeason? season,
    int? episodeNumber,
    String? episodeName,
    int? episodeRuntime,
    required DateTime watchedAt,
    double? rating,
    String? comment,
  }) async {
    final saved = _ensureFilm(film);
    if (season != null) _ensureSeason(saved, season);
    _history = [
      ..._history,
      HistoryEntry(
        id: _nextId(),
        filmId: saved.id!,
        seasonNumber: season?.seasonNumber,
        episodeNumber: episodeNumber,
        episodeName: episodeName,
        episodeRuntime: episodeRuntime,
        watchedAt: watchedAt,
        rating: rating,
        comment: comment,
      ),
    ];
    await Future.wait([_persistFilms(), _persistSeasons(), _persistHistory()]);
    _emit();
  }

  @override
  Future<void> addToWishlist(Film film, {FilmSeason? season}) async {
    final saved = _ensureFilm(film);
    if (season != null) _ensureSeason(saved, season);
    final already = _wishlist.any((e) =>
        e.filmId == saved.id && e.seasonNumber == season?.seasonNumber);
    if (already) return;
    _wishlist = [
      ..._wishlist,
      WishlistEntry(
        id: _nextId(),
        filmId: saved.id!,
        seasonNumber: season?.seasonNumber,
        addedAt: DateTime.now(),
      ),
    ];
    await Future.wait([_persistFilms(), _persistSeasons(), _persistWishlist()]);
    _emit();
  }

  @override
  Future<void> removeFromWishlist(String id) async {
    final filmId = _wishlist.where((e) => e.id == id).firstOrNull?.filmId;
    _wishlist = _wishlist.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilm(filmId);
    await Future.wait([_persistFilms(), _persistSeasons(), _persistWishlist()]);
    _emit();
  }

  @override
  Future<void> updateHistory(
    String id, {
    required DateTime watchedAt,
    double? rating,
    String? comment,
  }) async {
    _history = _history
        .map((e) => e.id == id
            ? HistoryEntry(
                id: e.id,
                filmId: e.filmId,
                seasonNumber: e.seasonNumber,
                episodeNumber: e.episodeNumber,
                episodeName: e.episodeName,
                episodeRuntime: e.episodeRuntime,
                watchedAt: watchedAt,
                rating: rating,
                comment: comment,
              )
            : e)
        .toList();
    await _persistHistory();
    _emit();
  }

  @override
  Future<void> updateHistoryEpisodeMeta(
    String id, {
    String? episodeName,
    int? episodeRuntime,
  }) async {
    if (episodeName == null && episodeRuntime == null) return;
    _history = _history
        .map((e) => e.id == id
            ? HistoryEntry(
                id: e.id,
                filmId: e.filmId,
                seasonNumber: e.seasonNumber,
                episodeNumber: e.episodeNumber,
                episodeName: episodeName ?? e.episodeName,
                episodeRuntime: episodeRuntime ?? e.episodeRuntime,
                watchedAt: e.watchedAt,
                rating: e.rating,
                comment: e.comment,
              )
            : e)
        .toList();
    await _persistHistory();
    _emit();
  }

  @override
  Future<void> removeFromCollection(String id) async {
    final filmId = _collection.where((e) => e.id == id).firstOrNull?.filmId;
    _collection = _collection.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilm(filmId);
    await Future.wait([_persistFilms(), _persistSeasons(), _persistCollection()]);
    _emit();
  }

  @override
  Future<void> removeFromHistory(String id) async {
    final filmId = _history.where((e) => e.id == id).firstOrNull?.filmId;
    _history = _history.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilm(filmId);
    await Future.wait([_persistFilms(), _persistSeasons(), _persistHistory()]);
    _emit();
  }

  /// GC applicatif : film/saison orphelin → retiré du catalogue.
  void _gcFilm(String filmId) {
    final filmRef = _collection.any((e) => e.filmId == filmId) ||
        _history.any((e) => e.filmId == filmId) ||
        _wishlist.any((e) => e.filmId == filmId);
    if (!filmRef) {
      final film = _filmsById.remove(filmId);
      if (film != null) _filmsByKey.remove(film.mediaKey);
      _seasons = _seasons.where((s) => s.filmId != filmId).toList();
      return;
    }
    // Nettoyage des saisons orphelines du film conservé.
    _seasons = _seasons.where((s) {
      if (s.filmId != filmId) return true;
      final used = _collection.any(
              (e) => e.filmId == filmId && e.seasonNumber == s.seasonNumber) ||
          _history.any(
              (e) => e.filmId == filmId && e.seasonNumber == s.seasonNumber) ||
          _wishlist.any(
              (e) => e.filmId == filmId && e.seasonNumber == s.seasonNumber);
      return used;
    }).toList();
  }

  @override
  Future<void> refresh() async {
    _load();
    _emit();
  }

  @override
  Future<void> backfillFilm(Film fresh) async {
    final existing = _filmsByKey[fresh.mediaKey];
    if (existing == null) return;
    final merged = _mergeFilm(existing, fresh);
    if (_sameMeta(existing, merged)) return;
    _filmsById[existing.id!] = merged;
    _filmsByKey[merged.mediaKey] = merged;
    await _persistFilms();
    _emit();
  }

  @override
  void dispose() {
    _collectionCtrl.close();
    _historyCtrl.close();
    _wishlistCtrl.close();
  }
}

/// SharedPreferences injecté depuis `main()` (override du ProviderScope) en mode local.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider non initialisé'),
);

/// Renvoie le bon backend selon la configuration (cloud si Supabase, sinon local).
/// Recréé au changement d'auth en mode cloud (et nettoie ses souscriptions).
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  if (AppConfig.hasSupabase) {
    ref.watch(currentUserProvider);
    // Consultation admin : le repository est reconstruit ciblé sur l'autre
    // utilisateur (lecture seule), et tout le pipeline de vues suit.
    final target = ref.watch(viewAsProvider);
    final repo = SupabaseLibraryRepository(
      ref.watch(supabaseClientProvider),
      ref.watch(sharedPreferencesProvider),
      targetUserId: target?.userId,
    );
    ref.onDispose(repo.dispose);
    return repo;
  }
  final repo = LocalLibraryRepository(ref.watch(sharedPreferencesProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

/// Flux de la collection (possessions enrichies).
final collectionStreamProvider = StreamProvider<List<CollectionView>>(
    (ref) => ref.watch(libraryRepositoryProvider).watchCollection());

/// Flux de l'historique (visionnages enrichis), du plus récent au plus ancien.
final historyStreamProvider = StreamProvider<List<HistoryView>>(
    (ref) => ref.watch(libraryRepositoryProvider).watchHistory());

/// Flux du pense-bête (titres à voir/acheter), du plus récent au plus ancien.
final wishlistStreamProvider = StreamProvider<List<WishlistView>>(
    (ref) => ref.watch(libraryRepositoryProvider).watchWishlist());

/// Index du pense-bête par clé `mediaKey|saison` — pour afficher l'état du
/// marque-page (recherche, fiche détail) et retrouver l'id à retirer.
final wishlistByKeyProvider = Provider<Map<String, WishlistView>>((ref) {
  final list = ref.watch(wishlistStreamProvider).value ?? const [];
  return {for (final w in list) '${w.film.mediaKey}|${w.seasonNumber}': w};
});

// ---------------------------------------------------------------------------
// Providers dérivés partagés (évitent de recalculer ces maps dans chaque écran)
// ---------------------------------------------------------------------------

/// Map mediaKey → premier Medium possédé (badges sur les vignettes de recherche).
final ownedMediumByKeyProvider = Provider.autoDispose<Map<String, Medium>>((ref) {
  final coll = ref.watch(collectionStreamProvider).value ?? [];
  final map = <String, Medium>{};
  for (final c in coll) {
    map.putIfAbsent(c.film.mediaKey, () => c.medium);
  }
  return map;
});

/// Ensemble des mediaKey vus au moins une fois.
final watchedKeysProvider = Provider.autoDispose<Set<String>>((ref) {
  final hist = ref.watch(historyStreamProvider).value ?? [];
  return {for (final v in hist) v.film.mediaKey};
});

/// Saisons vues par œuvre (mediaKey → numéros de saisons), pour les bandeaux.
final watchedSeasonsByKeyProvider =
    Provider.autoDispose<Map<String, Set<int>>>((ref) {
  final hist = ref.watch(historyStreamProvider).value ?? [];
  final map = <String, Set<int>>{};
  for (final v in hist) {
    if (v.seasonNumber != null) {
      (map[v.film.mediaKey] ??= {}).add(v.seasonNumber!);
    }
  }
  return map;
});

/// Map clé → ensemble de Medium possédés.
/// Chaque entrée est indexée sous sa clé `"${mediaKey}|${seasonNumber}|${episodeNumber}"`
/// (pour les badges sur toutes les cartes du même film) et, si liée à un
/// visionnage, aussi sous `"hist:{historyId}"` (pour la correspondance exacte).
final ownedMediumsByKeySeasonProvider =
    Provider.autoDispose<Map<String, Set<Medium>>>((ref) {
  final coll = ref.watch(collectionStreamProvider).value ?? [];
  final map = <String, Set<Medium>>{};
  for (final c in coll) {
    final mediaKey = '${c.film.mediaKey}|${c.seasonNumber}|${c.episodeNumber}';
    (map[mediaKey] ??= {}).add(c.medium);
    if (c.historyId != null) {
      (map['hist:${c.historyId}'] ??= {}).add(c.medium);
    }
  }
  return map;
});

/// Toutes les saisons connues par œuvre (history + collection),
/// pour les pastilles grises des saisons non encore vues.
final knownSeasonsByKeyProvider =
    Provider.autoDispose<Map<String, Set<int>>>((ref) {
  final hist = ref.watch(historyStreamProvider).value ?? [];
  final coll = ref.watch(collectionStreamProvider).value ?? [];
  final map = <String, Set<int>>{};
  for (final e in hist) {
    if (e.seasonNumber != null) {
      (map[e.film.mediaKey] ??= {}).add(e.seasonNumber!);
    }
  }
  for (final c in coll) {
    if (c.seasonNumber != null) {
      (map[c.film.mediaKey] ??= {}).add(c.seasonNumber!);
    }
  }
  return map;
});

/// Note moyenne par œuvre (mediaKey → double).
/// Films : moyenne de tous les visionnages notés (entrées sans saison).
/// Séries : moyenne des moyennes par saison (entrées saison sans épisode).
final ratingByKeyProvider = Provider.autoDispose<Map<String, double>>((ref) {
  final hist = ref.watch(historyStreamProvider).value ?? [];
  final movieRatings = <String, List<double>>{};
  final seasonRatings = <String, Map<int, List<double>>>{};

  for (final v in hist) {
    if (v.rating == null) continue;
    final key = v.film.mediaKey;
    if (v.seasonNumber == null) {
      (movieRatings[key] ??= []).add(v.rating!);
    } else if (v.episodeNumber == null) {
      ((seasonRatings[key] ??= {})[v.seasonNumber!] ??= []).add(v.rating!);
    }
  }

  final map = <String, double>{};

  for (final entry in movieRatings.entries) {
    map[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
  }

  for (final entry in seasonRatings.entries) {
    final seasonAvgs = entry.value.values
        .map((r) => r.reduce((a, b) => a + b) / r.length)
        .toList();
    map[entry.key] = seasonAvgs.reduce((a, b) => a + b) / seasonAvgs.length;
  }

  return map;
});

/// Note moyenne par œuvre+saison ("mediaKey|seasonNumber" → double).
/// Clé : "movie:123|null" (film) ou "tv:456|2" (saison précise).
/// Seules les entrées sans épisode sont prises en compte.
final ratingByKeySeasonProvider =
    Provider.autoDispose<Map<String, double>>((ref) {
  final hist = ref.watch(historyStreamProvider).value ?? [];
  final buckets = <String, List<double>>{};

  for (final v in hist) {
    if (v.rating == null || v.episodeNumber != null) continue;
    final key = '${v.film.mediaKey}|${v.seasonNumber}';
    (buckets[key] ??= []).add(v.rating!);
  }

  return {
    for (final e in buckets.entries)
      e.key: e.value.reduce((a, b) => a + b) / e.value.length,
  };
});
