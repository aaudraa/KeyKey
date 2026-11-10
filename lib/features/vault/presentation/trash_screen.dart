import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Çöp kutusu. Kayıtlar 30 gün sonra kendiliğinden kalıcı olarak silinir.
class TrashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    final controller = ref.read(loginsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trashTitle)),
      body: switch (state) {
        LoginsLoading() => const Center(child: CircularProgressIndicator()),
        LoginsLoaded(:final trashed) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.trashInfo(LoginRepository.trashRetention.inDays),
              ),
            ),
            Expanded(
              child: trashed.isEmpty
                  ? Center(child: Text(l10n.trashEmpty))
                  : ListView(
                      children: [
                        for (final item in trashed)
                          ListTile(
                            title: Text(item.content.name),
                            subtitle: item.content.username.isEmpty
                                ? null
                                : Text(item.content.username),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: l10n.trashRestore,
                                  icon: const Icon(Icons.restore),
                                  onPressed: () => controller.restore(item),
                                ),
                                IconButton(
                                  tooltip: l10n.trashDelete,
                                  icon: const Icon(Icons.delete_forever),
                                  onPressed: () =>
                                      _confirmDelete(context, controller, item),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LoginsController controller,
    LoginItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showKkConfirm(
      context,
      title: l10n.trashDeleteTitle,
      message: l10n.trashDeleteMessage(item.content.name),
      confirmLabel: l10n.trashDelete,
      cancelLabel: l10n.biometricCancel,
      destructive: true,
    );
    if (confirmed) await controller.deletePermanently(item);
  }
}
