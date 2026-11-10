import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

/// Ayarlardaki "Yedek ve aktarım" grubu: yedek alma ve son yedeğin zamanı,
/// geri yükleme, içe ve dışa aktarma.
class BackupSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  Future<void> _backUp() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await backUpVault(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final last = settings?.lastBackupAt;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return KkSection(
      title: l10n.settingsGroupBackup,
      children: [
        KkInfoRow(
          infoTitle: l10n.backupCreate,
          info: l10n.backupHelp,
          child: ListTile(
            leading: _busy
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            title: Text(l10n.backupCreate),
            subtitle: KkRowSubtitle(
              last == null
                  ? l10n.backupNever
                  : l10n.backupLast(
                      DateFormat.yMMMd(locale).add_Hm().format(last.toLocal()),
                    ),
            ),
            enabled: !_busy,
            onTap: () => unawaited(_backUp()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore),
          title: Text(l10n.restoreTitle),
          subtitle: KkRowSubtitle(l10n.restoreHelp),
          enabled: !_busy,
          onTap: () => unawaited(pickBackupToRestore(context, ref)),
        ),
        ListTile(
          leading: const Icon(Icons.input),
          title: Text(l10n.loginImportTitle),
          subtitle: KkRowSubtitle(l10n.loginImportHelp),
          enabled: !_busy,
          onTap: () => unawaited(pickLoginExport(context, ref)),
        ),
        ListTile(
          leading: const Icon(Icons.phonelink_lock_outlined),
          title: Text(l10n.otpImportSettingsTitle),
          subtitle: KkRowSubtitle(l10n.otpImportSettingsHelp),
          enabled: !_busy,
          onTap: () => unawaited(importFromFile(context, ref)),
        ),
        ListTile(
          leading: const Icon(Icons.output),
          title: Text(l10n.exportTitle),
          subtitle: KkRowSubtitle(l10n.exportHelp),
          enabled: !_busy,
          onTap: () => unawaited(exportPlaintext(context, ref)),
        ),
      ],
    );
  }
}
