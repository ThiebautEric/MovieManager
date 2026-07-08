import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_providers.dart';

/// Utilisateur tel que renvoyé par l'edge function `admin-users`.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.createdAt,
    this.lastSignInAt,
    required this.isAdmin,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] as String,
        email: (j['email'] as String?) ?? '(sans e-mail)',
        createdAt: DateTime.parse(j['created_at'] as String),
        lastSignInAt: j['last_sign_in_at'] == null
            ? null
            : DateTime.parse(j['last_sign_in_at'] as String),
        isAdmin: j['is_admin'] == true,
      );

  final String id;
  final String email;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final bool isAdmin;
}

/// Liste des utilisateurs + opérations admin, via l'edge function `admin-users`
/// (seule détentrice de la clé service_role ; vérifie elle-même la claim admin).
class AdminUsersController extends AsyncNotifier<List<AdminUser>> {
  @override
  Future<List<AdminUser>> build() => _fetch();

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final res = await ref
        .read(supabaseClientProvider)
        .functions
        .invoke('admin-users', body: body);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<List<AdminUser>> _fetch() async {
    final data = await _invoke({'action': 'list'});
    return (data['users'] as List)
        .map((e) => AdminUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }

  Future<void> createUser(String email, String password) async {
    await _invoke({'action': 'create', 'email': email, 'password': password});
    state = AsyncData(await _fetch());
  }

  Future<void> deleteUser(String userId) async {
    await _invoke({'action': 'delete', 'userId': userId});
    state = AsyncData(await _fetch());
  }
}

final adminUsersProvider =
    AsyncNotifierProvider<AdminUsersController, List<AdminUser>>(
        AdminUsersController.new);
