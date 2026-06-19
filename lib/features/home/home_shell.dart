import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/collection_repository.dart';
import '../../widgets/poster_image.dart';
import '../auth/auth_controller.dart';
import '../collection/collection_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      ref.read(collectionRepositoryProvider).refresh();
    }
  }

  static const _pages = [
    CollectionScreen(),
    SearchScreen(),
    StatsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
        icon: Icon(Icons.video_library_outlined),
        selectedIcon: Icon(Icons.video_library),
        label: 'Collection'),
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
