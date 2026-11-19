import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_animated_items.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/record_avatar.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/application/vault_entries.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/trash_actions.dart';
import 'package:keykey/features/vault/presentation/vault_entry_tiles.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Çöp kutusu: parola, kart ve notlar birlikte. Kayıtlar 30 gün sonra
/// kendiliğinden kalıcı olarak silinir.
class TrashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(vaultEntriesProvider);

    final trashed = switch (state) {
      VaultEntriesLoaded(:final trashed) => sortEntries(
        trashed,
        LoginSort.recentlyUpdated,
      ),
      VaultEntriesLoading() => const <VaultEntry>[],
    };
    return KkScaffold(
      appBar: kkAppBar(
        context,
        title: l10n.trashTitle,
        actions: [
          TrashActions(
            count: trashed.length,
            emptyMessage: l10n.trashEmptyMessage(trashed.length),
            onRestoreAll: () async {
              for (final entry in [...trashed]) {
                await _restore(ref, entry);
              }
            },
            onEmptyAll: () async {
              for (final entry in [...trashed]) {
                await _delete(ref, entry);
              }
            },
          ),
        ],
      ),
      body: switch (state) {
        VaultEntriesLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        VaultEntriesLoaded() => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.trashInfo(LoginRepository.trashRetention.inDays),
              ),
            ),
            Expanded(
              child: KkItemsView<VaultEntry>(
                items: trashed,
                keyOf: (entry) => '${entry.kind.name}:${loginIdHex(entry.id)}',
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                empty: Text(l10n.trashEmpty, textAlign: TextAlign.center),
                itemBuilder: (context, entry, index) => KkCard(
                  leading: switch (entry) {
                    LoginEntry(:final item) => RecordAvatar(
                      login: item.content,
                      name: item.content.name,
                    ),
                    CardEntry() => RecordAvatar(
                      login: null,
                      name: entry.name,
                      icon: Icons.credit_card_rounded,
                    ),
                    NoteEntry() => RecordAvatar(
                      login: null,
                      name: entry.name,
                      icon: Icons.sticky_note_2_outlined,
                    ),
                  },
                  title: Text(switch (entry) {
                    CardEntry(:final item) => cardTitle(item),
                    _ => entry.name.trim().isEmpty ? '—' : entry.name,
                  }),
                  subtitle: switch (entry) {
                    LoginEntry(:final item) when item.content.username != '' =>
                      Text(item.content.username),
                    CardEntry(:final item) => Text(
                      cardSummary(l10n, item, DateTime.now()),
                    ),
                    _ => null,
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.trashRestore,
                        icon: Icon(
                          Icons.restore_rounded,
                          color: KkGlass.of(context).accent,
                        ),
                        onPressed: () => _restore(ref, entry),
                      ),
                      IconButton(
                        tooltip: l10n.trashDelete,
                        icon: Icon(
                          Icons.delete_forever_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => _confirmDelete(context, ref, entry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      },
    );
  }

  static Future<void> _restore(WidgetRef ref, VaultEntry entry) =>
      switch (entry) {
        LoginEntry(:final item) =>
          ref.read(loginsControllerProvider.notifier).restore(item),
        CardEntry(:final item) =>
          ref.read(cardsControllerProvider.notifier).restore(item),
        NoteEntry(:final item) =>
          ref.read(notesControllerProvider.notifier).restore(item),
      };

  static Future<void> _delete(WidgetRef ref, VaultEntry entry) =>
      switch (entry) {
        LoginEntry(:final item) =>
          ref.read(loginsControllerProvider.notifier).deletePermanently(item),
        CardEntry(:final item) =>
          ref.read(cardsControllerProvider.notifier).deletePermanently(item),
        NoteEntry(:final item) =>
          ref.read(notesControllerProvider.notifier).deletePermanently(item),
      };

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VaultEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showKkConfirm(
      context,
      title: l10n.trashDeleteTitle,
      message: l10n.trashDeleteMessage(entry.name),
      confirmLabel: l10n.trashDelete,
      cancelLabel: l10n.biometricCancel,
      destructive: true,
    );
    if (confirmed) await _delete(ref, entry);
  }
}
