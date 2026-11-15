import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/presentation/confirm_identity.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/data/export/bitwarden_csv_export.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Önerilen dosya adı: `keykey-disa-aktarma-2026-11-07.csv`.
String plaintextExportFileName(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = time.toLocal();
  return 'keykey-disa-aktarma-${local.year}-${two(local.month)}-'
      '${two(local.day)}.csv';
}

/// Kasayı şifresiz Bitwarden CSV'si olarak kullanıcının seçtiği yere
/// kaydeder.
///
/// Önce dosyanın şifresiz olduğu anlatılır, sonra parmak izi veya ana
/// parolayla kimlik doğrulanır. Dosya yalnızca belge seçicinin verdiği yere
/// yazılır; uygulamanın klasöründe kopya kalmaz.
Future<void> exportPlaintext(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final warned = await showKkConfirm(
    context,
    title: l10n.exportWarningTitle,
    message: l10n.exportWarningBody,
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
    final logins = await ref
        .read(loginRepositoryFactoryProvider)(status.session)
        .loadAll();
    final otps = await ref
        .read(otpRepositoryFactoryProvider)(status.session)
        .loadAll();
    bytes = Uint8List.fromList(
      utf8.encode(
        BitwardenCsvExport.build(logins: logins.items, otps: otps.items),
      ),
    );
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
          suggestedName: plaintextExportFileName(now),
          mimeType: 'text/csv',
          bytes: bytes,
        ),
      );
  switch (result) {
    case DocumentSaveResult.saved:
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportSaved)));
    case DocumentSaveResult.cancelled:
      break;
    case DocumentSaveResult.failed:
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
  }
}
