import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_version.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../auth/auth_controller.dart';
import '../backup/backup_service.dart';

class AccountSheet extends ConsumerStatefulWidget {
  const AccountSheet({super.key});

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<AccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportBackup() async {
    setState(() => _loading = true);
    try {
      final bytes = await ref.read(backupServiceProvider).export();
      final now = DateTime.now();
      final d = '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      await FileSaver.instance.saveFile(
        name: 'sauvegarde_$d',
        bytes: bytes,
        fileExtension: 'zip',
        mimeType: MimeType.zip,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sauvegarde exportée.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importBackup() async {
    final cs = Theme.of(context).colorScheme;

    final clearFirst = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer une sauvegarde'),
        content: const Text(
          'Voulez-vous effacer vos données actuelles avant la restauration, '
          'ou les conserver et fusionner ?\n\n'
          'Écraser est recommandé pour une restauration complète ou une '
          'migration vers un nouveau compte.\n\n'
          'En mode fusion, les visionnages peuvent être dupliqués.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Fusionner'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Écraser mes données'),
          ),
        ],
      ),
    );
    if (clearFirst == null || !mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    setState(() => _loading = true);
    try {
      final stats = await ref
          .read(backupServiceProvider)
          .importZip(bytes, clearFirst: clearFirst);
      await ref.read(libraryRepositoryProvider).refresh();
      ref.invalidate(favoritesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import réussi : ${stats.films} films, '
              '${stats.history} visionnages, '
              '${stats.collection} possessions, '
              '${stats.wishlist} pense-bêtes, '
              '${stats.favorites} favoris.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur import : ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = false;
    });
    try {
      await ref
          .read(authControllerProvider)
          .updatePassword(_pwdCtrl.text.trim());
      if (mounted) {
        setState(() {
          _success = true;
          _loading = false;
        });
        _pwdCtrl.clear();
        _confirmCtrl.clear();
      }
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.account_circle, size: 22, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user?.email ?? '',
                    style: tt.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Changer le mot de passe',
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pwdCtrl,
              obscureText: _obscure1,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure1
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Minimum 6 caractères' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure2,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure2
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                ),
              ),
              validator: (v) => v != _pwdCtrl.text
                  ? 'Les mots de passe ne correspondent pas'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 13)),
            ],
            if (_success) ...[
              const SizedBox(height: 8),
              Text('Mot de passe mis à jour.',
                  style: TextStyle(color: Colors.green.shade600, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Mettre à jour'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Sauvegarde',
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exporter toutes les données (.zip)'),
              onPressed: _loading ? null : _exportBackup,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Importer une sauvegarde (.zip)'),
              onPressed: _loading ? null : _importBackup,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider).signOut();
              },
            ),
            const SizedBox(height: 12),
            Text(
              'v$kDeployVersion',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
