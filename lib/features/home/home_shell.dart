import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_version.dart';
import '../../core/l10n/l10n.dart';
import '../../core/supabase/view_as.dart';
import '../../data/models/film.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/models/collection_entry.dart';
import '../../data/models/history_entry.dart';
import '../../tmdb/models/season_episodes.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/account_button.dart';
import '../../widgets/poster_image.dart';
import '../admin/admin_screen.dart';
import '../friends/friends_screen.dart';
import '../collection/collection_screen.dart';
import '../collection/physical_collection_screen.dart';
import '../favorites/favorites_screen.dart';
import '../search/details_library_controls.dart';
import '../search/details_screen.dart';
import '../search/person_screen.dart';
import '../search/search_screen.dart';
import '../stats/stats_screen.dart';
import '../top10/top10_screen.dart';
import '../wishlist/wishlist_screen.dart';
import 'selected_media.dart';

/// Coquille principale avec navigation (Collection / Recherche / Statistiques).
///
/// Sur grand écran : barre latérale persistante (liens + affiche de la fiche
/// ouverte) et les fiches s'empilent dans la zone de droite (maître-détail).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  bool _backfilling = false;

  /// Version des métadonnées capturées. À incrémenter quand on enrichit le
  /// modèle (v1 : pays/casting ; v2 : + réalisateurs ; v3 : casting complet,
  /// plus limité à 15 ; v4-v5 : affiches en langue originale — v5 corrige le
  /// filtre de langue TMDB qui masquait les affiches originales). Un
  /// changement de version déclenche un rafraîchissement complet **une fois**.
  static const _backfillVersion = 5;
  static const _backfillKey = 'metadata_backfill_version';


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 3));
      _backfillMetadata();
    });
  }

  /// Rafraîchit automatiquement les métadonnées (pays, casting, réalisateurs)
  /// de TOUTE la bibliothèque depuis TMDB — **une seule fois par version**, puis
  /// se tait (mémorisé dans SharedPreferences). `backfillFilm` n'écrit en base
  /// que si quelque chose a changé. Mode cloud uniquement (le local est complet
  /// dès l'ajout). Plus besoin de rouvrir chaque fiche.
  Future<void> _backfillMetadata() async {
    // Jamais pendant une consultation (repository lecture seule ciblé sur un
    // autre utilisateur) ni pour le compte admin (pas de bibliothèque).
    if (_backfilling ||
        !AppConfig.hasSupabase ||
        ref.read(isViewingAsProvider) ||
        ref.read(isAdminProvider)) {
      return;
    }
    _backfilling = true;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      // Refresh COMPLET une fois par version (nouveau type de métadonnée) ;
      // sinon on ne traite QUE les films aux métadonnées vides (ex. titres
      // importés), pour ne pas refaire d'appels TMDB inutiles.
      final fullRefresh = (prefs.getInt(_backfillKey) ?? 0) < _backfillVersion;

      final coll = await ref.read(collectionStreamProvider.future);
      final hist = await ref.read(historyStreamProvider.future);
      final films = <String, Film>{
        for (final c in coll) c.film.mediaKey: c.film,
        for (final h in hist) h.film.mediaKey: h.film,
      };
      final targets = fullRefresh
          ? films.values.toList()
          : films.values.where((f) => f.castIds.isEmpty).toList();

      final repo = ref.read(libraryRepositoryProvider);
      final tmdb = ref.read(tmdbClientProvider);
      for (final f in targets) {
        if (!mounted) break;
        try {
          final d = await tmdb.details(f.tmdbId, f.mediaType);
          await repo.backfillFilm(Film.fromDetails(d));
        } catch (_) {
          // titre introuvable / erreur réseau : on ignore et on continue.
        }
        // Petite pause entre chaque requête pour ne pas saturer l'API TMDB
        // ni déclencher trop de rebuilds Supabase en rafale.
        await Future.delayed(const Duration(milliseconds: 30));
      }
      // Marque cette version comme traitée : le refresh complet ne se relancera
      // plus (les futurs titres vides restent rattrapés ci-dessus).
      if (fullRefresh) await prefs.setInt(_backfillKey, _backfillVersion);

      // Phase 2 : durées exactes de saison (runtime_minutes dans film_seasons).
      // Re-tenté à chaque lancement tant qu'il reste des saisons sans durée :
      // TMDB peut ne pas avoir les données aujourd'hui mais les avoir demain.
      await _backfillSeasonRuntimes(repo, coll);

      // Phase 3 : épisodes du verlauf sans runtime — récupération depuis TMDB
      // (uniquement si TMDB fournit la valeur exacte ; sinon on n'écrit rien).
      await _backfillHistoryEpisodeRuntimes(repo, hist);
    } catch (_) {
      // pas connecté / données pas prêtes : on réessaiera au prochain lancement.
    } finally {
      _backfilling = false;
    }
  }

  /// Pour chaque saison en collection sans runtime_minutes, tente de calculer
  /// la somme exacte via TMDB. Ne sauvegarde QUE si TOUS les épisodes ont un
  /// runtime connu — sinon ne fait rien (re-tenté au prochain lancement).
  /// Traite 3 saisons en parallèle pour réduire le temps total.
  Future<void> _backfillSeasonRuntimes(
      LibraryRepository repo, List<CollectionView> coll) async {
    final tmdb = ref.read(tmdbClientProvider);

    // Dédupliquer par (filmId, seasonNumber) pour éviter N appels TMDB si
    // la même saison est possédée en DVD et en Blu-ray.
    final seen = <String>{};
    final targets = <({String filmId, int tmdbId, int seasonNumber})>[];
    for (final e in coll) {
      if (e.seasonNumber == null) continue;
      if (e.episodeNumber != null) continue;
      if (e.season?.runtimeMinutes != null) continue; // déjà connu
      if (e.film.id == null) continue;
      final key = '${e.film.id}:${e.seasonNumber}';
      if (seen.add(key)) {
        targets.add((
          filmId: e.film.id!,
          tmdbId: e.film.tmdbId,
          seasonNumber: e.seasonNumber!,
        ));
      }
    }

    // Traitement par lots de 3 requêtes simultanées.
    const batchSize = 3;
    for (int i = 0; i < targets.length; i += batchSize) {
      if (!mounted) return;
      final batch = targets.sublist(
          i, (i + batchSize).clamp(0, targets.length));
      await Future.wait(batch.map((t) async {
        try {
          final List<EpisodeInfo> eps =
              await tmdb.seasonEpisodes(t.tmdbId, t.seasonNumber);
          // N'enregistre que si TOUS les épisodes ont un runtime exact.
          if (eps.isEmpty) return;
          if (eps.any((e) => e.runtime == null || e.runtime! <= 0)) return;
          final sum = eps.fold<int>(0, (acc, e) => acc + e.runtime!);
          await repo.backfillSeasonRuntime(t.filmId, t.seasonNumber, sum);
        } catch (_) {
          // Réseau indisponible ou show introuvable : on réessaiera.
        }
      }));
      if (i + batchSize < targets.length) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }
  }

  /// Pour chaque épisode du verlauf sans runtime, tente de récupérer la durée
  /// exacte depuis TMDB et la sauvegarde. N'écrit rien si TMDB ne répond pas
  /// ou si l'épisode TMDB n'a pas de runtime. Traite 3 saisons en parallèle.
  Future<void> _backfillHistoryEpisodeRuntimes(
      LibraryRepository repo, List<HistoryView> hist) async {
    final tmdb = ref.read(tmdbClientProvider);

    // Grouper par (tmdbId, saison) pour n'appeler TMDB qu'une fois par saison.
    final byKey = <({int tmdbId, int season}), List<HistoryView>>{};
    for (final h in hist) {
      if (h.episodeNumber == null) continue;
      if (h.seasonNumber == null) continue;
      if (h.entry.episodeRuntime != null) continue; // déjà connu
      if (h.entry.id == null) continue;
      final key = (tmdbId: h.film.tmdbId, season: h.seasonNumber!);
      (byKey[key] ??= []).add(h);
    }
    if (byKey.isEmpty) return;

    final keys = byKey.keys.toList();
    const batchSize = 3;
    for (int i = 0; i < keys.length; i += batchSize) {
      if (!mounted) return;
      final batch = keys.sublist(i, (i + batchSize).clamp(0, keys.length));
      await Future.wait(batch.map((k) async {
        try {
          final eps = await tmdb.seasonEpisodes(k.tmdbId, k.season);
          final runtimeByEp = <int, int>{
            for (final e in eps)
              if (e.runtime != null && e.runtime! > 0) e.episodeNumber: e.runtime!,
          };
          // Fallback épisode individuel pour les spéciaux (saison 0) : l'endpoint
          // saison retourne souvent null même quand TMDB a la donnée.
          for (final h in byKey[k]!) {
            if (runtimeByEp.containsKey(h.episodeNumber!)) continue;
            try {
              final rt = await tmdb.episodeRuntime(
                  k.tmdbId, k.season, h.episodeNumber!);
              if (rt != null && rt > 0) runtimeByEp[h.episodeNumber!] = rt;
            } catch (_) {}
          }
          for (final h in byKey[k]!) {
            final rt = runtimeByEp[h.episodeNumber!];
            if (rt == null) continue;
            await repo.updateHistoryEpisodeMeta(h.entry.id!, episodeRuntime: rt);
          }
        } catch (_) {
          // Réseau indisponible ou épisode TMDB sans runtime : on réessaiera.
        }
      }));
      if (i + batchSize < keys.length) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour dans l'app, resynchronise avec la base (récupère les
    // changements faits ailleurs, ex. suppressions non reçues en temps réel).
    if (state == AppLifecycleState.resumed) {
      ref.read(libraryRepositoryProvider).refresh();
    }
  }

  // L'onglet « Mes amis » est ajouté en DERNIER (mode cloud), pour que les
  // index des 7 onglets de base ne bougent jamais.
  static const _basePages = <Widget>[
    CollectionScreen(),
    PhysicalCollectionScreen(),
    Top10Screen(),
    WishlistScreen(),
    FavoritesScreen(),
    SearchScreen(),
    StatsScreen(),
  ];

  static List<NavigationDestination> _baseDestinations(AppLocalizations l10n) =>
      [
        NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.historyTitle),
        NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library),
            label: l10n.collectionTitle),
        NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events),
            label: l10n.top10Title),
        NavigationDestination(
            icon: const Icon(Icons.bookmark_border),
            selectedIcon: const Icon(Icons.bookmark),
            label: l10n.wishlistTitle),
        NavigationDestination(
            icon: const Icon(Icons.star_border),
            selectedIcon: const Icon(Icons.star),
            label: l10n.favoritesTitle),
        NavigationDestination(
            icon: const Icon(Icons.search), label: l10n.searchTitle),
        NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l10n.navStats),
      ];

  static NavigationDestination _friendsDestination(AppLocalizations l10n) =>
      NavigationDestination(
          icon: const Icon(Icons.group_outlined),
          selectedIcon: const Icon(Icons.group),
          label: l10n.friendsTitle);

  void _selectTab(int i) {
    setState(() => _index = i);
    // Revenir à un onglet ferme la pile de fiches.
    closeDetail(ref);
  }

  Widget _buildEntry(DetailEntry entry, int depth) {
    return switch (entry) {
      MediaEntry e => DetailsScreen(
          key: ValueKey('m${e.id}_$depth'),
          mediaType: e.type,
          tmdbId: e.id,
          embedded: true,
        ),
      PersonEntry e => PersonScreen(
          key: ValueKey('p${e.id}_$depth'),
          personId: e.id,
          embedded: true,
        ),
      SeasonEntry e => SeasonScreen(
          key: ValueKey('s${e.details.tmdbId}_${e.info.seasonNumber}_$depth'),
          details: e.details,
          info: e.info,
          embedded: true,
        ),
      EpisodeEntry e => EpisodeScreen(
          key: ValueKey('ep${e.details.tmdbId}_${e.info.seasonNumber}_${e.episode.episodeNumber}_$depth'),
          details: e.details,
          info: e.info,
          episode: e.episode,
          embedded: true,
        ),
    };
  }

  /// Bande « lecture seule » affichée au-dessus du contenu pendant une
  /// consultation admin, dans les deux layouts.
  Widget _withViewAsBanner(Widget child) {
    final target = ref.watch(viewAsProvider);
    if (target == null) return child;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: cs.tertiaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 18, color: cs.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.navViewingAs(target.email),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onTertiaryContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(viewAsProvider.notifier).exit(),
                    child: Text(context.l10n.navQuit),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= kWideBreakpoint;
    final stack = ref.watch(detailStackProvider);
    final top = stack.isEmpty ? null : stack.last;

    final isAdmin = AppConfig.hasSupabase && ref.watch(isAdminProvider);

    // Compte admin : uniquement la gestion des comptes, pas de bibliothèque
    // ni d'onglets (NavigationBar exige d'ailleurs au moins 2 destinations).
    if (isAdmin) {
      return const AdminScreen();
    }

    final pages = [
      ..._basePages,
      if (AppConfig.hasSupabase) const FriendsScreen(),
    ];
    final destinations = [
      ..._baseDestinations(context.l10n),
      if (AppConfig.hasSupabase) _friendsDestination(context.l10n),
    ];
    // Le nombre d'onglets peut changer (reconnexion avec un autre compte).
    if (_index >= pages.length) _index = 0;

    // Entrée en consultation → onglet Historique (les données de l'ami) ;
    // sortie → retour sur le dernier onglet (« Mes amis »).
    ref.listen(viewAsProvider, (prev, next) {
      if (prev == null && next != null) {
        setState(() => _index = 0);
        closeDetail(ref);
      } else if (prev != null && next == null) {
        setState(() => _index = pages.length - 1);
        closeDetail(ref);
      }
    });

    final tabs = IndexedStack(index: _index, children: pages);

    if (isWide) {
      // tabs reste toujours dans le tree (Offstage quand un détail est ouvert)
      // pour préserver l'état local des écrans (champs de texte, scroll, etc.).
      final content = Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: top != null, child: tabs),
          if (top != null) _buildEntry(top, stack.length),
        ],
      );

      return Scaffold(
        body: Row(
          children: [
            _SideRail(
              index: _index,
              destinations: destinations,
              top: top,
              onSelect: _selectTab,
              showAccount: AppConfig.hasSupabase,
              onCloseDetail: () => closeDetail(ref),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _withViewAsBanner(content)),
          ],
        ),
      );
    }

    return Scaffold(
      body: _withViewAsBanner(tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: destinations,
      ),
    );
  }
}

/// Barre latérale : liens de navigation + affiche/photo de la fiche ouverte
/// (repère de position dans la hiérarchie).
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.destinations,
    required this.top,
    required this.onSelect,
    required this.showAccount,
    required this.onCloseDetail,
  });

  final int index;
  final List<NavigationDestination> destinations;
  final DetailEntry? top;
  final ValueChanged<int> onSelect;
  final bool showAccount;
  final VoidCallback onCloseDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (String? poster, String label) = switch (top) {
      MediaEntry e => (e.posterPath, e.title),
      PersonEntry e => (e.profilePath, e.name),
      SeasonEntry e => (
          e.info.posterPath,
          e.info.name.isNotEmpty ? e.info.name : 'S${e.info.seasonNumber}',
        ),
      EpisodeEntry e => (
          e.episode.stillPath,
          e.episode.name.isNotEmpty
              ? e.episode.name
              : 'E${e.episode.episodeNumber}',
        ),
      null => (null, ''),
    };

    return Column(
      children: [
        Expanded(
          child: NavigationRail(
            selectedIndex: index,
            onDestinationSelected: onSelect,
            labelType: NavigationRailLabelType.all,
            leading: showAccount
                ? const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: AccountButton(),
                  )
                : null,
            trailing: top == null
                ? null
                : Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Divider(),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 64,
                                height: 96,
                                child: PosterImage(posterPath: poster, size: 'w185'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 72,
                              child: Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.navCloseDetail,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: onCloseDetail,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            destinations: destinations
                .map((d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon ?? d.icon,
                      label: Text(d.label),
                    ))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'v$kDeployVersion',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
