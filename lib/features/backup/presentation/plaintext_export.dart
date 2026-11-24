import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/presentation/confirm_identity.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/application/plaintext_exporter.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

export 'package:keykey/features/backup/application/plaintext_exporter.dart'
    show ExportFormat;

/// Önerilen dosya adı: `keykey-disa-aktarma-2026-11-07.csv`. [prefix]
/// arayüz dilinden gelir (`keykey-export`).
String plaintextExportFileName(
  DateTime time, {
  String prefix = 'keykey-disa-aktarma',
  String extension = 'csv',
}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = time.toLocal();
  return '$prefix-${local.year}-${two(local.month)}-'
      '${two(local.day)}.$extension';
}

/// Biçimi sorar; vazgeçilirse `null`. [hasCards] ise CSV'nin kartları
/// yazmadığı söylenir.
Future<ExportFormat?> showExportFormatChoice(
  BuildContext context, {
  required bool hasCards,
}) {
  final l10n = AppLocalizations.of(context);
  return showKkSheet<ExportFormat>(
    context,
    builder: (context) => KkSheetContent(
      title: l10n.exportFormatTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.exportWarningCancel),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l10n.exportFormatCsv),
            subtitle: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.exportFormatCsvHint),
                if (hasCards)
                  Text(
                    l10n.exportFormatCsvNoCards,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            onTap: () => Navigator.of(context).pop(ExportFormat.csv),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.data_object_rounded),
            title: Text(l10n.exportFormatJson),
            subtitle: Text(l10n.exportFormatJsonHint),
            onTap: () => Navigator.of(context).pop(ExportFormat.json),
          ),
        ],
      ),
    ),
  );
}

/// Kasayı şifresiz Bitwarden CSV'si ya da JSON'u olarak kullanıcının
/// seçtiği yere kaydeder.
///
/// Önce biçim seçilir, sonra dosyanın şifresiz olduğu anlatılır, sonra
/// parmak izi veya ana parolayla kimlik doğrulanır. Dosya yalnızca belge
/// seçicinin verdiği yere yazılır; uygulamanın klasöründe kopya kalmaz.
Future<void> exportPlaintext(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final snack = kkSnackFor(context);
  final opened = ref.read(vaultControllerProvider);
  if (opened is! VaultOpen) return;
  final exporter = ref.read(plaintextExporterProvider);
  final bool hasCards;
  final bool hasPasskeys;
  try {
    hasCards = await exporter.hasCards(opened.session);
    hasPasskeys = await exporter.hasPasskeys(opened.session);
  } on VaultLockedException {
    return;
  }
  if (!context.mounted) return;
  final format = await showExportFormatChoice(context, hasCards: hasCards);
  if (format == null || !context.mounted) return;
  final warned = await showKkConfirm(
    context,
    title: l10n.exportWarningTitle,
    message: hasPasskeys
        ? '${l10n.exportWarningBody}\n\n${l10n.exportPasskeysNote}'
        : l10n.exportWarningBody,
    confirmLabel: l10n.exportWarningContinue,
    cancelLabel: l10n.exportWarningCancel,
  );
  if (!warned || !context.mounted) return;
  if (!await confirmIdentity(context, ref, title: l10n.exportConfirmTitle)) {
    return;
  }
  final status = ref.read(vaultControllerProvider);
  if (status is! VaultOpen) return;
  final Uint8List bytes;
  try {
    bytes = await exporter.build(status.session, format);
  } on VaultLockedException {
    return;
  }
  final now = ref.read(backupClockProvider)();
  final files = ref.read(documentFilesProvider);
  // Baytlar kaydedildikten sonra DocumentFiles tarafından sıfırlanır.
  final result = await ref
      .read(externalActivityGateProvider.notifier)
      .run(
        () => files.save(
          suggestedName: plaintextExportFileName(
            now,
            prefix: l10n.exportFilePrefix,
            extension: format.name,
          ),
          mimeType: switch (format) {
            ExportFormat.csv => 'text/csv',
            ExportFormat.json => 'application/json',
          },
          bytes: bytes,
        ),
      );
  switch (result) {
    case DocumentSaveResult.saved:
      snack(l10n.exportSaved);
    case DocumentSaveResult.cancelled:
      break;
    case DocumentSaveResult.failed:
      snack(l10n.exportFailed);
  }
}
