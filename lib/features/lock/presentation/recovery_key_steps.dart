import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/recovery_key_text.dart';
import 'package:keykey/features/lock/presentation/recovery_key_formatter.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

// Kurtarma anahtarını gösterme ve geri yazdırma adımlarının ortak parçaları.
// Kasa kurulumunda ve yeni kurtarma anahtarında kullanılır.
//
// `gated` kasa açıkken `true` olur: dosya seçici açıkken arka plan kilidi
// çalışmasın diye seçici dış etkinlik kapısından geçer. Kurulumda kasa
// olmadığı için kapı kullanılmaz (guvenlik-tasarimi.md, Kasa oluşturma).

/// Opak uyarı kartı: okunurluğu zemine bağlı kalmasın.
class RecoveryWarningCard extends StatelessWidget {
  const new({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}

/// Anahtarın kendisi, altında "Kopyala" ve "Dosyaya kaydet".
class RecoveryKeyCard extends ConsumerWidget {
  const new({
    required this.text,
    required this.gated,
    this.allowCopy = true,
    super.key,
  });

  final String text;
  final bool gated;

  /// Kasa açıkken kapalı: kopyalayıp başka uygulamaya geçmek kasayı
  /// kilitler.
  final bool allowCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontFamily: 'monospace', height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            if (allowCopy)
              TextButton.icon(
                // Güvenli pano: 30 saniye sonra temizlenir.
                onPressed: () => copySensitive(context, ref, text),
                icon: const Icon(Icons.copy_rounded),
                label: Text(l10n.recoveryCopy),
              ),
            TextButton.icon(
              onPressed: () =>
                  saveRecoveryKeyFile(context, ref, text, gated: gated),
              icon: const Icon(Icons.save_alt_rounded),
              label: Text(l10n.recoverySaveFile),
            ),
          ],
        ),
      ],
    );
  }
}

/// Anahtarı yazma kutusu ve altında "Dosyadan oku".
class RecoveryKeyEntry extends ConsumerWidget {
  const new({
    required this.controller,
    required this.enabled,
    required this.gated,
    required this.onChanged,
    required this.onRead,
    required this.onSubmitted,
    this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool gated;
  final String? errorText;

  /// Kutuya yazıldıkça.
  final VoidCallback onChanged;

  /// Anahtar dosyadan okunup kutuya yazılınca.
  final VoidCallback onRead;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          padding: const EdgeInsets.all(4),
          child: SecretField(
            controller: controller,
            label: l10n.recoveryKeyLabel,
            obscure: false,
            autofocus: true,
            enabled: enabled,
            errorText: errorText,
            helperText: l10n.recoveryKeyProgress(
              RecoveryKeyText.symbolsOf(controller.text).length,
              RecoveryKeyText.textLength,
            ),
            // Tireler kendiliğinden gelir; uzun anahtar satıra sığmazsa alta
            // geçer.
            inputFormatters: [RecoveryKeyFormatter()],
            style: const TextStyle(fontFamily: 'monospace'),
            maxLines: 3,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: enabled
                ? () async {
                    if (await readRecoveryKeyFile(
                      context,
                      ref,
                      controller,
                      gated: gated,
                    )) {
                      onRead();
                    }
                  }
                : null,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(l10n.recoveryReadFile),
          ),
        ),
      ],
    );
  }
}

/// Yazılan anahtarın neresinin yanlış olduğunu söyler: eksik veya fazla
/// karakter, yoksa farklı olan ilk grup. Anahtar zaten ekranda gösterildi;
/// karşılaştırma yalnızca yol gösterir, asıl doğrulama kurtarma yuvası
/// açılarak yapılır.
String recoveryKeyMismatchHint(
  AppLocalizations l10n, {
  required String? shown,
  required String typed,
  required String fallback,
}) {
  if (shown == null) return fallback;
  final typedSymbols = RecoveryKeyText.symbolsOf(typed);
  final expected = RecoveryKeyText.symbolsOf(shown);
  if (typedSymbols.length != expected.length) {
    return l10n.recoveryKeyLength(typedSymbols.length, expected.length);
  }
  const size = RecoveryKeyText.groupLength;
  for (var start = 0; start < expected.length; start += size) {
    final end = (start + size).clamp(0, expected.length);
    if (typedSymbols.substring(start, end) != expected.substring(start, end)) {
      return l10n.recoveryKeyGroupWrong(start ~/ size + 1);
    }
  }
  return fallback;
}

Future<T> _external<T>(
  WidgetRef ref,
  Future<T> Function() action, {
  required bool gated,
}) => gated
    ? ref.read(externalActivityGateProvider.notifier).run(action)
    : action();

/// Anahtarı kullanıcının seçtiği yere metin dosyası olarak kaydeder.
Future<void> saveRecoveryKeyFile(
  BuildContext context,
  WidgetRef ref,
  String text, {
  required bool gated,
}) async {
  final l10n = AppLocalizations.of(context);
  final snack = kkSnackFor(context);
  final files = ref.read(documentFilesProvider);
  final result = await _external(
    ref,
    () => files.save(
      suggestedName: l10n.recoveryFileName,
      mimeType: 'text/plain',
      bytes: utf8.encode('${l10n.recoveryFileHeader}\n$text\n'),
    ),
    gated: gated,
  );
  switch (result) {
    case DocumentSaveResult.saved:
      snack(l10n.recoveryFileSaved);
    case DocumentSaveResult.failed:
      snack(l10n.recoveryFileFailed);
    case DocumentSaveResult.cancelled:
      break;
  }
}

/// Kaydedilmiş dosyadan anahtarı okuyup [controller]'a yazar. Anahtar,
/// karakterleri tam bir anahtar uzunluğunda olan ilk satırdır. Yazdıysa
/// `true`.
Future<bool> readRecoveryKeyFile(
  BuildContext context,
  WidgetRef ref,
  TextEditingController controller, {
  required bool gated,
}) async {
  final l10n = AppLocalizations.of(context);
  final snack = kkSnackFor(context);
  final files = ref.read(documentFilesProvider);
  final result = await _external(
    ref,
    () => files.open(mimeTypes: const ['text/plain'], maxBytes: 4096),
    gated: gated,
  );
  if (result is DocumentOpenCancelled) return false;
  String? line;
  if (result is DocumentOpened) {
    final text = utf8.decode(result.bytes, allowMalformed: true);
    result.bytes.fillRange(0, result.bytes.length, 0);
    for (final candidate in const LineSplitter().convert(text)) {
      if (RecoveryKeyText.symbolsOf(candidate).length ==
          RecoveryKeyText.textLength) {
        line = candidate;
        break;
      }
    }
  }
  if (!context.mounted) return false;
  if (line == null) {
    snack(l10n.recoveryFileNoKey);
    return false;
  }
  controller.value = RecoveryKeyFormatter().formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(text: line.trim()),
  );
  return true;
}
