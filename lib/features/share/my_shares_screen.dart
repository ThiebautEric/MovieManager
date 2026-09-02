import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/format.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/empty_state.dart';
import 'share_service.dart';

/// Écran « Mes liens partagés » : lister et révoquer les liens de partage créés.
class MySharesScreen extends ConsumerWidget {
  const MySharesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMd(locale);
    final async = ref.watch(mySharesProvider);

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(l10n.mySharesTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(message: l10n.errorMessage(friendlyError(e))),
        data: (shares) {
          if (shares.isEmpty) {
            return EmptyState(message: l10n.mySharesEmpty);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: shares.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = shares[i];
              final url = shareUrlForToken(s.token);
              return ListTile(
                leading: const Icon(Icons.link),
                title: Text(l10n.sharedHistoryTitle),
                subtitle: Text(
                  s.createdAt != null
                      ? dateFmt.format(s.createdAt!.toLocal())
                      : url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.shareCopyLink,
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.shareCopied)),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: l10n.shareRevoke,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.shareRevoke),
                            content: Text(l10n.shareRevokeConfirm),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(l10n.shareRevoke),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        await revokeShare(ref, s.token);
                        ref.invalidate(mySharesProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
