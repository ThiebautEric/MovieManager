import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_providers.dart';

/// Un autre utilisateur de l'app, dont la bibliothèque est consultable.
class Friend {
  const Friend({required this.userId, required this.email});

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        userId: j['user_id'] as String,
        email: (j['email'] as String?) ?? '(sans e-mail)',
      );

  final String userId;
  final String email;
}

/// Liste des autres comptes, via la fonction SQL `public.friends()`
/// (SECURITY DEFINER : renvoie id + email de tous les comptes sauf le sien).
class FriendsController extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    // Rechargée à chaque changement de compte.
    ref.watch(currentUserProvider);
    final rows = await ref.read(supabaseClientProvider).rpc('friends');
    return (rows as List)
        .map((e) => Friend.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final friendsProvider =
    AsyncNotifierProvider<FriendsController, List<Friend>>(
        FriendsController.new);
