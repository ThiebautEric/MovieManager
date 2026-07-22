import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/l10n.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/language_button.dart';
import '../../widgets/theme_toggle_button.dart';
import '../auth/auth_controller.dart';
import 'admin_controller.dart';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Message lisible extrait d'une erreur (FunctionException porte le JSON
/// renvoyé par l'edge function dans `details`).
String _errorMessage(AppLocalizations l10n, Object e) {
  if (e is FunctionException) {
    final details = e.details;
    if (details is Map && details['message'] != null) {
      return details['message'].toString();
    }
    if (details is Map && details['error'] == 'email_exists') {
      return l10n.adminEmailExists;
    }
    return l10n.adminHttpError(e.status);
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(l10n.adminTitle),
        actions: [
          const LanguageButton(),
          const ThemeToggleButton(),
          // Seul écran du compte admin : la déconnexion vit ici.
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.adminCreateUser,
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
                Text(l10n.adminLoadFailed(_errorMessage(l10n, error)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(adminUsersProvider),
                  child: Text(l10n.adminRetry),
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
        title: Text(context.l10n.adminCreateUser),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration:
                    InputDecoration(labelText: context.l10n.authEmailLabel),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                validator: (v) => (v == null || !v.contains('@'))
                    ? context.l10n.authEmailInvalid
                    : null,
              ),
              TextFormField(
                controller: passwordCtrl,
                decoration:
                    InputDecoration(labelText: context.l10n.authPasswordLabel),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6)
                    ? context.l10n.authPasswordTooShort
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text(context.l10n.adminCreate),
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
          SnackBar(
              content: Text(
                  context.l10n.adminUserCreated(emailCtrl.text.trim()))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n
                  .adminActionFailed(_errorMessage(context.l10n, e)))),
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
    final l10n = context.l10n;
    final lastSeen = user.lastSignInAt != null
        ? l10n.adminLastSignIn(_fmtDate(user.lastSignInAt!))
        : l10n.adminNeverSignedIn;

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
            Chip(
              label: Text(l10n.adminBadge),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
          if (isSelf) ...[
            const SizedBox(width: 8),
            Text(l10n.adminYou, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      subtitle:
          Text('${l10n.adminCreatedOn(_fmtDate(user.createdAt))} · $lastSeen'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip:
            user.isAdmin || isSelf ? l10n.adminCannotDelete : l10n.delete,
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
        title: Text(context.l10n.adminDeleteUserTitle(user.email)),
        content: Text(context.l10n.adminDeleteUserWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.delete),
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
          SnackBar(
              content: Text(context.l10n
                  .adminActionFailed(_errorMessage(context.l10n, e)))),
        );
      }
    }
  }
}
