import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../data/models/film.dart';
import '../../data/models/film_season.dart';
import '../../data/models/history_entry.dart';
import '../collection/collection_filter.dart';
import '../collection/history_sort.dart';

/// Domaine de production (utilisé pour bâtir les liens depuis l'APK ; sur le web
/// on prend l'origine réelle pour couvrir les déploiements de préversion).
const String kShareBaseUrl = 'https://theyellowframe.pages.dev';

/// Lien partageable (route publique en hash) pour un token donné.
String shareUrlForToken(String token) {
  final origin = kIsWeb ? Uri.base.origin : kShareBaseUrl;
  return '$origin/#/partage?t=$token';
}

/// Erreur « lien invalide ou révoqué » — remontée quand le token n'existe plus.
class ShareUnavailable implements Exception {
  const ShareUnavailable();
}

/// Un lien de partage tel que listé côté propriétaire (écran « Mes liens »).
class ShareInfo {
  const ShareInfo({
    required this.token,
    required this.view,
    required this.createdAt,
    this.label,
  });

  final String token;
  final String view;
  final DateTime? createdAt;
  final String? label;

  factory ShareInfo.fromJson(Map<String, dynamic> j) => ShareInfo(
        token: j['token'] as String,
        view: j['view'] as String,
        label: j['label'] as String?,
        createdAt: j['created_at'] == null
            ? null
            : DateTime.tryParse(j['created_at'] as String),
      );
}

/// Contenu résolu d'un lien partagé : l'historique du propriétaire (en direct)
/// plus l'état initial de filtre et de tri encodé dans le lien.
class SharedHistoryData {
  const SharedHistoryData({
    required this.history,
    required this.filter,
    required this.sort,
  });

  final List<HistoryView> history;
  final CollectionFilter filter;
  final HistorySort sort;
}

/// Crée un lien de partage de l'historique pour l'utilisateur courant et
/// renvoie son token (via la RPC `create_share`, côté propriétaire connecté).
Future<String> createHistoryShare(
  WidgetRef ref, {
  required CollectionFilter filter,
  required HistorySort sort,
}) async {
  final client = ref.read(supabaseClientProvider);
  final token = await client.rpc('create_share', params: {
    'p_view': 'history',
    'p_filter': filter.toJson(),
    'p_sort': sort.name,
  });
  return token as String;
}

/// Liste des liens de partage du propriétaire (pour révocation).
final mySharesProvider = FutureProvider.autoDispose<List<ShareInfo>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('shares')
      .select()
      .order('created_at', ascending: false);
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(ShareInfo.fromJson)
      .toList();
});

/// Révoque (supprime) un lien de partage du propriétaire.
Future<void> revokeShare(WidgetRef ref, String token) async {
  final client = ref.read(supabaseClientProvider);
  await client.from('shares').delete().eq('token', token);
}

/// Contenu d'un lien partagé, résolu en anonyme via les RPC confinées au token.
/// Charge les métadonnées (`get_share`) puis les données (`share_history_snapshot`)
/// et reconstruit les [HistoryView] (même jointure que le dépôt).
final sharedHistoryProvider =
    FutureProvider.family<SharedHistoryData, String>((ref, token) async {
  final client = ref.watch(supabaseClientProvider);

  final metaRows = await client.rpc('get_share', params: {'p_token': token});
  final metaList = (metaRows as List?)?.cast<Map<String, dynamic>>() ?? const [];
  if (metaList.isEmpty) throw const ShareUnavailable();
  final meta = metaList.first;

  final snap = await client
      .rpc('share_history_snapshot', params: {'p_token': token}) as Map;

  final films = (snap['films'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(Film.fromJson)
      .toList();
  final filmsById = {for (final f in films) f.id!: f};
  final seasons = (snap['seasons'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(FilmSeason.fromJson)
      .toList();
  final seasonByKey = <String, FilmSeason>{
    for (final s in seasons)
      if (s.filmId != null) '${s.filmId}|${s.seasonNumber}': s,
  };
  final entries = (snap['history'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(HistoryEntry.fromJson)
      .toList();

  final views = <HistoryView>[];
  for (final e in entries) {
    final film = filmsById[e.filmId];
    if (film == null) continue;
    views.add(HistoryView(
      entry: e,
      film: film,
      season: e.seasonNumber == null
          ? null
          : seasonByKey['${e.filmId}|${e.seasonNumber}'],
    ));
  }
  views.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));

  return SharedHistoryData(
    history: views,
    filter: CollectionFilter.fromJson(
        (meta['filter'] as Map?)?.cast<String, dynamic>() ?? const {}),
    sort: historySortFromName(meta['sort'] as String?),
  );
});
