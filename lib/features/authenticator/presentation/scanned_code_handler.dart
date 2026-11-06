import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/core/platform/qr_image_reader.dart';
import 'package:keykey/features/authenticator/application/scanned_code.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Okunan QR'ı işler: hesapsa onay ekranını açar, değilse nedenini söyler.
///
/// [replace] ise açılan ekran bulunulan ekranın yerine geçer, örneğin
/// tarama ekranı onay ekranıyla değişir.
Future<void> handleScannedCode(
  BuildContext context,
  ScannedCode scanned, {
  required bool replace,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final String message;
  switch (scanned) {
    case OtpauthCode(:final account):
      if (replace) {
        context.pushReplacement(AppRoutes.authenticatorNew, extra: account);
      } else {
        await context.push(AppRoutes.authenticatorNew, extra: account);
      }
      return;
    case MigrationCode():
      // Google Authenticator içe aktarması ayrı görevde geliyor.
      message = l10n.otpLinkUnsupported;
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
}

/// Fotoğraf seçiciyle bir görsel seçtirir ve içindeki QR'ı işler.
Future<void> readQrFromImage(
  BuildContext context,
  WidgetRef ref, {
  required bool replace,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(qrImageReaderProvider).pickAndRead();
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
