import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/search/details_screen.dart';
import '../../features/search/person_screen.dart';
import '../../features/search/saga_screen.dart';
import '../../features/share/shared_history_screen.dart';
import '../../features/share/my_shares_screen.dart';
import '../config/app_config.dart';
import '../supabase/supabase_providers.dart';

/// Routeur de l'application.
///
/// - Mode cloud (Supabase) : redirection selon l'état d'authentification.
/// - Mode local : accès direct à l'app, sans connexion.
final routerProvider = Provider<GoRouter>((ref) {
  final routes = [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/', builder: (_, _) => const HomeShell()),
    // Route PUBLIQUE (sans connexion) : historique partagé en lecture seule.
    GoRoute(
      path: '/partage',
      builder: (_, state) =>
          SharedHistoryScreen(token: state.uri.queryParameters['t'] ?? ''),
    ),
    GoRoute(path: '/mes-liens', builder: (_, _) => const MySharesScreen()),
    GoRoute(
      path: '/media/:type/:id',
      builder: (_, state) => DetailsScreen(
        mediaType: state.pathParameters['type']!,
        tmdbId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/person/:id',
      builder: (_, state) =>
          PersonScreen(personId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/saga/:id',
      builder: (_, state) =>
          SagaScreen(collectionId: int.parse(state.pathParameters['id']!)),
    ),
  ];

  if (!AppConfig.hasSupabase) {
    // Mode local : pas d'auth, on n'accède pas à Supabase.
    return GoRouter(initialLocation: '/', routes: routes);
  }

  final client = ref.watch(supabaseClientProvider);
  final refresh = GoRouterRefreshStream(client.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final goingToLogin = state.matchedLocation == '/login';
      // La vue partagée est publique : accessible sans authentification.
      final publicShare = state.matchedLocation == '/partage';
      if (!loggedIn) return (goingToLogin || publicShare) ? null : '/login';
      if (goingToLogin) return '/';
      return null;
    },
    routes: routes,
  );
});

/// Adapte un Stream en Listenable pour le `refreshListenable` de go_router.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
