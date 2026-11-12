import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/presentation/scanned_code_handler.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/presentation/login_import_screen.dart';
import 'package:keykey/features/backup/presentation/plaintext_export.dart';
import 'package:keykey/features/backup/presentation/restore_screen.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Açık kasanın yedeğini üretir ve kullanıcının seçtiği yere kaydeder.
///
/// Dosya kasa açıkken üretilir; seçici açıkken yalnızca şifreli baytlar
/// bekler. Başarılıysa son yedek zamanı ayar kaydına yazılır.
Future<void> backUpVault(BuildContext context, WidgetRef ref) async {
  final status = ref.read(vaultControllerProvider);
  if (status is! VaultOpen) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final settings = ref.read(settingsControllerProvider.notifier);
  final files = ref.read(documentFilesProvider);
  final now = ref.read(backupClockProvider)();
  final Uint8List bytes;
  try {
    bytes = await ref.read(backupServiceProvider).create(status.session, now);
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
}

/// Ayarlardaki "Yedek ve aktarım" grubu: geri yükleme, içe ve dışa
/// aktarma. Yedek alma ayarların en üstündeki `BackupStatusCard`'da.
class BackupSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    const chevron = Icon(Icons.chevron_right_rounded);
    return KkSection(
      title: l10n.settingsGroupBackup,
      children: [
        ListTile(
          leading: const KkIconBox(icon: Icons.settings_backup_restore_rounded),
          title: Text(l10n.restoreTitle),
          subtitle: KkRowSubtitle(l10n.restoreHelp),
          trailing: chevron,
          onTap: () => unawaited(pickBackupToRestore(context, ref)),
        ),
        ListTile(
          leading: const KkIconBox(icon: Icons.input_rounded),
          title: Text(l10n.loginImportTitle),
          subtitle: KkRowSubtitle(l10n.loginImportHelp),
          trailing: chevron,
          onTap: () => unawaited(pickLoginExport(context, ref)),
        ),
        ListTile(
          leading: const KkIconBox(icon: Icons.phonelink_lock_rounded),
          title: Text(l10n.otpImportSettingsTitle),
          subtitle: KkRowSubtitle(l10n.otpImportSettingsHelp),
          trailing: chevron,
          onTap: () => unawaited(importFromFile(context, ref)),
        ),
        ListTile(
          leading: const KkIconBox(icon: Icons.output_rounded),
          title: Text(l10n.exportTitle),
          subtitle: KkRowSubtitle(l10n.exportHelp),
          trailing: chevron,
          onTap: () => unawaited(exportPlaintext(context, ref)),
        ),
      ],
    );
  }
}
