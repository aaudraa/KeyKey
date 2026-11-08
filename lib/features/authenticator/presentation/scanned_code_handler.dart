import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/core/platform/export_file_picker.dart';
import 'package:keykey/core/platform/qr_image_reader.dart';
import 'package:keykey/features/authenticator/application/otp_import.dart';
import 'package:keykey/features/authenticator/application/scanned_code.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/features/authenticator/data/import/platform_aes_gcm.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Okunan QR'ı işler: hesapsa onay ekranını, Google Authenticator dışa
/// aktarmasıysa içe aktarma ekranını açar, değilse nedenini söyler.
///
/// [replace] ise açılan ekran bulunulan ekranın yerine geçer, örneğin
/// tarama ekranı onay ekranıyla değişir. Bir ekran açıldıysa `true` döner.
Future<bool> handleScannedCode(
  BuildContext context,
  ScannedCode scanned, {
  required bool replace,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final String message;
  switch (scanned) {
    case OtpauthCode(:final account):
      await _open(context, AppRoutes.authenticatorNew, account, replace);
      return true;
    case MigrationCode(:final text):
      try {
        final source = ImportSource.fromMigration(text);
        if (!context.mounted) return false;
        await _open(context, AppRoutes.authenticatorImport, source, replace);
        return true;
      } on InvalidImportException {
        message = l10n.otpImportFailed;
      }
    case InvalidOtpauthCode(:final error):
      message = error == OtpauthError.unsupportedType
          ? l10n.otpLinkUnsupported
          : l10n.otpLinkInvalid;
    case UnrelatedCode():
      message = l10n.otpScanNotOtp;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  return false;
}

Future<void> _open(
  BuildContext context,
  String route,
  Object extra,
  bool replace,
) async {
  if (replace) {
    context.pushReplacement(route, extra: extra);
  } else {
    await context.push(route, extra: extra);
  }
}

/// Fotoğraf seçiciyle bir görsel seçtirir ve içindeki QR'ı işler.
Future<void> readQrFromImage(
  BuildContext context,
  WidgetRef ref, {
  required bool replace,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final reader = ref.read(qrImageReaderProvider);
  final result = await ref
      .read(externalActivityGateProvider.notifier)
      .run(reader.pickAndRead);
  if (!context.mounted) return;
  switch (result) {
    case QrImageCancelled():
      return;
    case QrImageNotFound():
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.otpImageNoQr)));
    case QrImageRead(:final text):
      await handleScannedCode(
        context,
        ScannedCode.classify(text),
        replace: replace,
      );
  }
}

/// Aegis veya 2FAS dışa aktarma dosyası seçtirir ve içe aktarma ekranını
/// açar.
Future<void> importFromFile(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void show(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  final picker = ref.read(exportFilePickerProvider);
  final result = await ref
      .read(externalActivityGateProvider.notifier)
      .run(picker.pickAndRead);
  if (!context.mounted) return;
  switch (result) {
    case ExportFileCancelled():
      return;
    case ExportFileTooLarge():
      show(l10n.otpImportUnknownFile);
    case ExportFileRead(:final bytes):
      final ImportSource source;
      try {
        source = ImportSource.fromFile(bytes, ref.read(aesGcmProvider));
      } on UnknownImportFileException {
        show(l10n.otpImportUnknownFile);
        return;
      } on InvalidImportException {
        show(l10n.otpImportFailed);
        return;
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      await context.push(AppRoutes.authenticatorImport, extra: source);
  }
}
