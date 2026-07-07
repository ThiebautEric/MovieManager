import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/models/film.dart';
import '../../data/repositories/collection_repository.dart';
import '../../tmdb/tmdb_providers.dart';
import '../../widgets/poster_image.dart';
import '../auth/auth_controller.dart';
import '../collection/collection_screen.dart';
import '../collection/physical_collection_screen.dart';
import '../favorites/favorites_screen.dart';
import '../search/details_screen.dart';
import '../search/person_screen.dart';
import '../search/search_screen.dart';
import '../stats/stats_screen.dart';
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
  /// modèle (v1 : pays/casting ; v2 : + réalisateurs). Un changement de version
  /// déclenche un rafraîchissement complet **une seule fois**.
  static const _backfillVersion = 2;
  static const _backfillKey = 'metadata_backfill_version';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _backfillMetadata());
  }

  /// Rafraîchit automatiquement les métadonnées (pays, casting, réalisateurs)
  /// de TOUTE la bibliothèque depuis TMDB — **une seule fois par version**, puis
  /// se tait (mémorisé dans SharedPreferences). `backfillFilm` n'écrit en base
  /// que si quelque chose a changé. Mode cloud uniquement (le local est complet
  /// dès l'ajout). Plus besoin de rouvrir chaque fiche.
  Future<void> _backfillMetadata() async {
    if (_backfilling || !AppConfig.hasSupabase) return;
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
        try {
          final d = await tmdb.details(f.tmdbId, f.mediaType);
          await repo.backfillFilm(Film.fromDetails(d));
        } catch (_) {
          // titre introuvable / erreur réseau : on ignore et on continue.
        }
      }
      // Marque cette version comme traitée : le refresh complet ne se relancera
      // plus (les futurs titres vides restent rattrapés ci-dessus).
      if (fullRefresh) await prefs.setInt(_backfillKey, _backfillVersion);
    } catch (_) {
      // pas connecté / données pas prêtes : on réessaiera au prochain lancement.
    } finally {
      _backfilling = false;
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

  static const _pages = [
    CollectionScreen(),
    PhysicalCollectionScreen(),
    FavoritesScreen(),
    SearchScreen(),
    StatsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'Historique'),
    NavigationDestination(
        icon: Icon(Icons.video_library_outlined),
        selectedIcon: Icon(Icons.video_library),
        label: 'Collection'),
    NavigationDestination(
        icon: Icon(Icons.star_border),
        selectedIcon: Icon(Icons.star),
        label: 'Favoris'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Rechercher'),
    NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Stats'),
  ];

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
    };
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= kWideBreakpoint;
    final stack = ref.watch(detailStackProvider);
    final top = stack.isEmpty ? null : stack.last;

    final tabs = IndexedStack(index: _index, children: _pages);

    if (isWide) {
      final content =
          top == null ? tabs : _buildEntry(top, stack.length);

      return Scaffold(
        body: Row(
          children: [
            _SideRail(
              index: _index,
              destinations: _destinations,
              top: top,
              onSelect: _selectTab,
              onSignOut: AppConfig.hasSupabase
                  ? () => ref.read(authControllerProvider).signOut()
                  : null,
              onCloseDetail: () => closeDetail(ref),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: tabs,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: _destinations,
      ),
      floatingActionButton: (_index == 0 && AppConfig.hasSupabase)
          ? FloatingActionButton(
              tooltip: 'Se déconnecter',
              mini: true,
              child: const Icon(Icons.logout),
              onPressed: () => ref.read(authControllerProvider).signOut(),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
    required this.onSignOut,
    required this.onCloseDetail,
  });

  final int index;
  final List<NavigationDestination> destinations;
  final DetailEntry? top;
  final ValueChanged<int> onSelect;
  final VoidCallback? onSignOut;
  final VoidCallback onCloseDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (String? poster, String label) = switch (top) {
      MediaEntry e => (e.posterPath, e.title),
      PersonEntry e => (e.profilePath, e.name),
      null => (null, ''),
    };

    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      leading: onSignOut == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                tooltip: 'Se déconnecter',
                icon: const Icon(Icons.logout),
                onPressed: onSignOut,
              ),
            ),
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
                          child:
                              PosterImage(posterPath: poster, size: 'w185'),
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
                        tooltip: 'Fermer la fiche',
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
    );
  }
}
