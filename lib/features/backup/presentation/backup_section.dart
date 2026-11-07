import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ayarlar ekranında yedek alma ve son yedeğin zamanı.
class BackupSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  Future<void> _backUp() async {
    final status = ref.read(vaultControllerProvider);
    if (_busy || status is! VaultOpen) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsControllerProvider.notifier);
    final files = ref.read(documentFilesProvider);
    final now = ref.read(backupClockProvider)();
    setState(() => _busy = true);
    try {
      // Dosya kasa açıkken üretilir; seçici açıkken yalnızca şifreli baytlar
      // bekler.
      final Uint8List bytes;
      try {
        bytes = await ref
            .read(backupServiceProvider)
            .create(status.session, now);
      } on VaultLockedException {
        return;
      }
      final result = await ref
          .read(externalActivityGateProvider.notifier)
          .run(
            () => files.save(
              suggestedName: BackupService.fileNameFor(now),
              mimeType: BackupService.mimeType,
              bytes: bytes,
            ),
          );
      switch (result) {
        case DocumentSaveResult.saved:
          try {
            await settings.recordBackup(now);
          } on VaultLockedException {
            // Dosya kaydedildi; kasa kilitlendiği için zaman yazılamadı.
          }
          messenger.showSnackBar(SnackBar(content: Text(l10n.backupSaved)));
        case DocumentSaveResult.cancelled:
          break;
        case DocumentSaveResult.failed:
          messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final last = settings?.lastBackupAt;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: _busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt),
          title: Text(l10n.backupCreate),
          subtitle: Text(
            last == null
                ? l10n.backupNever
                : l10n.backupLast(
                    DateFormat.yMMMd(locale).add_Hm().format(last.toLocal()),
                  ),
          ),
          enabled: !_busy,
          onTap: () => unawaited(_backUp()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
          child: Text(
            l10n.backupHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
