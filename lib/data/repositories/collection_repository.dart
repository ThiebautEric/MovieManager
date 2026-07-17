import 'dart:async';
import 'dart:convert';

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

  /// Resynchronise avec la source de vérité (autres appareils).
  Future<void> refresh();

  void dispose();
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
    _intSetEq(a.genres, b.genres) &&
    _intSetEq(a.castIds, b.castIds);

// ===========================================================================
// Backend cloud : 4 tables Supabase écoutées en temps réel et jointes en
// mémoire en vues composites (CollectionView / HistoryView).
// ===========================================================================
class SupabaseLibraryRepository implements LibraryRepository {
  SupabaseLibraryRepository(this._client, {this._targetUserId});

  final SupabaseClient _client;

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
      _loadAll();
    }
  }

  /// Charge une table en entier en paginant (PostgREST plafonne à 1000 lignes
  /// par requête ; on enchaîne les pages jusqu'à épuisement).
  Future<List<Map<String, dynamic>>> _selectAll(String table) async {
    const pageSize = 1000;
    final out = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final rows = await _client
          .from(table)
          .select()
          .eq('user_id', _userId)
          .order('id')
          .range(from, from + pageSize - 1);
      final list = (rows as List).cast<Map<String, dynamic>>();
      out.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }
    return out;
  }

  Future<void> _loadAll() async {
    final films = await _selectAll('films');
    final seasons = await _selectAll('film_seasons');
    final coll = await _selectAll('collection');
    final hist = await _selectAll('history');
    // Tolère l'absence de la table (migration SQL pas encore exécutée) : le
    // pense-bête est alors vide mais le reste de la bibliothèque fonctionne.
    List<Map<String, dynamic>> wish;
    try {
      wish = await _selectAll('wishlist');
    } catch (_) {
      wish = const [];
    }
    final fl = films.map(Film.fromJson).toList();
    _filmsById = {for (final f in fl) f.id!: f};
    _filmsByKey = {for (final f in fl) f.mediaKey: f};
    _seasons = seasons.map(FilmSeason.fromJson).toList();
    _collection = coll.map(CollectionEntry.fromJson).toList();
    _history = hist.map(HistoryEntry.fromJson).toList();
    _wishlist = wish.map(WishlistEntry.fromJson).toList();
    _rebuild();
  }

  void _rebuild() {
    final seasonByKey = <String, FilmSeason>{
      for (final s in _seasons)
        if (s.filmId != null) _seasonKey(s.filmId!, s.seasonNumber): s,
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
    required Medium medium,
    DateTime? addedAt,
  }) async {
    _assertWritable();
    final saved = await _upsertFilm(film);
    if (season != null) await _upsertSeason(saved, season);

    // Évite le doublon exact (film, saison, support) — `null` n'est pas dédupé
    // par la contrainte unique côté Postgres.
    final already = _collection.any((e) =>
        e.filmId == saved.id &&
        e.seasonNumber == season?.seasonNumber &&
        e.medium == medium);
    if (already) return;

    final entry = CollectionEntry(
      filmId: saved.id!,
      seasonNumber: season?.seasonNumber,
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
      'episode_name': ?episodeName,
      'episode_runtime': ?episodeRuntime,
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
    _filmsById = {for (final f in films) f.id!: f};
    _filmsByKey = {for (final f in films) f.mediaKey: f};
    _seasons = _decode(_seasonsKey, FilmSeason.fromJson);
    _collection = _decode(_collectionKey, CollectionEntry.fromJson);
    _history = _decode(_historyKey, HistoryEntry.fromJson);
    _wishlist = _decode(_wishlistKey, WishlistEntry.fromJson);
  }

  Future<void> _persist() async {
    await _prefs.setString(_filmsKey,
        jsonEncode(_filmsById.values.map((e) => e.toFullJson()).toList()));
    await _prefs.setString(
        _seasonsKey, jsonEncode(_seasons.map((e) => e.toFullJson()).toList()));
    await _prefs.setString(_collectionKey,
        jsonEncode(_collection.map((e) => e.toFullJson()).toList()));
    await _prefs.setString(
        _historyKey, jsonEncode(_history.map((e) => e.toFullJson()).toList()));
    await _prefs.setString(
        _wishlistKey, jsonEncode(_wishlist.map((e) => e.toFullJson()).toList()));
    _emit();
  }

  void _emit() {
    final seasonByKey = <String, FilmSeason>{
      for (final s in _seasons)
        if (s.filmId != null) _seasonKey(s.filmId!, s.seasonNumber): s,
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
    _collectionCtrl.add(List.unmodifiable(coll));
    _historyCtrl.add(List.unmodifiable(hist));
    _wishlistCtrl.add(List.unmodifiable(wish));
  }

  @override
  Stream<List<CollectionView>> watchCollection() async* {
    _emit();
    yield* _collectionCtrl.stream;
  }

  @override
  Stream<List<HistoryView>> watchHistory() async* {
    _emit();
    yield* _historyCtrl.stream;
  }

  @override
  Stream<List<WishlistView>> watchWishlist() async* {
    _emit();
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
    );
    _filmsById[id] = saved;
    _filmsByKey[saved.mediaKey] = saved;
    return saved;
  }

  void _ensureSeason(Film film, FilmSeason season) {
    final saved = FilmSeason(
      id: '${film.id}#${season.seasonNumber}',
      filmId: film.id,
      seasonNumber: season.seasonNumber,
      name: season.name,
      posterPath: season.posterPath,
      airYear: season.airYear,
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
    required Medium medium,
    DateTime? addedAt,
  }) async {
    final saved = _ensureFilm(film);
    if (season != null) _ensureSeason(saved, season);
    final already = _collection.any((e) =>
        e.filmId == saved.id &&
        e.seasonNumber == season?.seasonNumber &&
        e.medium == medium);
    if (already) return;
    _collection = [
      ..._collection,
      CollectionEntry(
        id: _nextId(),
        filmId: saved.id!,
        seasonNumber: season?.seasonNumber,
        medium: medium,
        addedAt: addedAt ?? DateTime.now(),
      ),
    ];
    await _persist();
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
    await _persist();
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
    await _persist();
  }

  @override
  Future<void> removeFromWishlist(String id) async {
    final filmId = _wishlist
        .where((e) => e.id == id)
        .map((e) => e.filmId)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    _wishlist = _wishlist.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilm(filmId);
    await _persist();
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
    await _persist();
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
    await _persist();
  }

  @override
  Future<void> removeFromCollection(String id) async {
    final filmId = _collection
        .where((e) => e.id == id)
        .map((e) => e.filmId)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    _collection = _collection.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilm(filmId);
    await _persist();
  }

  @override
  Future<void> removeFromHistory(String id) async {
    final filmId = _history
        .where((e) => e.id == id)
        .map((e) => e.filmId)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    _history = _history.where((e) => e.id != id).toList();
    if (filmId != null) _gcFilm(filmId);
    await _persist();
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
    await _persist();
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
