import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../widgets/theme_toggle_button.dart';
import '../auth/auth_controller.dart';
import 'admin_controller.dart';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Message lisible extrait d'une erreur (FunctionException porte le JSON
/// renvoyé par l'edge function dans `details`).
String _errorMessage(Object e) {
  if (e is FunctionException) {
    final details = e.details;
    if (details is Map && details['message'] != null) {
      return details['message'].toString();
    }
    if (details is Map && details['error'] == 'email_exists') {
      return 'Cet e-mail existe déjà.';
    }
    return 'Erreur ${e.status}';
  }
  return e.toString();
}

/// Écran « Admin » : liste des utilisateurs, création, suppression,
/// consultation de la bibliothèque d'un utilisateur (lecture seule).
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminUsersProvider);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          const ThemeToggleButton(),
          // Seul écran du compte admin : la déconnexion vit ici.
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Créer un utilisateur',
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
      body: switch (async) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.read(adminUsersProvider.notifier).reload(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: value.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _UserTile(user: value[i], isSelf: value[i].id == me?.id),
            ),
          ),
        AsyncError(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('Chargement impossible : ${_errorMessage(error)}',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(adminUsersProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer un utilisateur'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
              ),
              TextFormField(
                controller: passwordCtrl,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6)
                    ? '6 caractères minimum'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (created != true || !context.mounted) return;
    try {
      await ref
          .read(adminUsersProvider.notifier)
          .createUser(emailCtrl.text.trim(), passwordCtrl.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Utilisateur ${emailCtrl.text.trim()} créé.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec : ${_errorMessage(e)}')),
        );
      }
    }
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user, required this.isSelf});

  final AdminUser user;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSeen = user.lastSignInAt != null
        ? 'dernière connexion ${_fmtDate(user.lastSignInAt!)}'
        : 'jamais connecté';

    return ListTile(
      leading: CircleAvatar(
        child: Icon(user.isAdmin ? Icons.shield : Icons.person),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(user.email, overflow: TextOverflow.ellipsis),
          ),
          if (user.isAdmin) ...[
            const SizedBox(width: 8),
            const Chip(
              label: Text('admin'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
          if (isSelf) ...[
            const SizedBox(width: 8),
            Text('(vous)', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      subtitle: Text('Créé le ${_fmtDate(user.createdAt)} · $lastSeen'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: user.isAdmin || isSelf
            ? 'Suppression impossible (admin)'
            : 'Supprimer',
        onPressed: user.isAdmin || isSelf
            ? null
            : () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer ${user.email} ?'),
        content: const Text(
            'Toutes ses données (collection, historique, favoris) seront '
            'définitivement effacées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(adminUsersProvider.notifier).deleteUser(user.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec : ${_errorMessage(e)}')),
        );
      }
    }
  }
}
