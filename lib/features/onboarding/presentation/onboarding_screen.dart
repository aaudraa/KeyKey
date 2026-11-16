import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/backup/presentation/restore_screen.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/new_password_fields.dart';
import 'package:keykey/features/lock/presentation/recovery_key_formatter.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

enum _Step { password, showKey, verifyKey }

/// Kasa oluşturma. Kurtarma anahtarı doğrulanana kadar diske bir şey yazılmaz.
class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// Adım göstergesi (testler için; madde 4.7).
  static const Key stepIndicatorKey = ValueKey('kk-setup-steps');

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _typedKey = TextEditingController();
  late final VaultController _controller;

  _Step _step = _Step.password;
  String? _recoveryKeyText;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(vaultControllerProvider.notifier);
  }

  @override
  void dispose() {
    _controller.cancelSetup();
    _password.dispose();
    _confirmation.dispose();
    _typedKey.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_busy && NewPasswordFields.isValid(_password.text, _confirmation.text);

  Future<void> _create() async {
    if (!_canCreate) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = await _controller.prepareVault(_password.text);
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      setState(() {
        _recoveryKeyText = text;
        _step = _Step.showKey;
      });
    } on Exception {
      if (mounted) setState(() => _error = l10n.setupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _typedKey.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _controller.confirmSetup(_typedKey.text);
    } on InvalidRecoveryKeyException {
      if (mounted) {
        setState(() => _error = _mismatchHint(l10n, l10n.recoveryKeyInvalid));
      }
    } on WrongSecretException {
      if (mounted) {
        setState(() => _error = _mismatchHint(l10n, l10n.recoveryKeyWrong));
      }
    } on Exception {
      if (mounted) setState(() => _error = l10n.setupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Yazılan anahtarın neresinin yanlış olduğunu söyler: eksik veya fazla
  /// karakter, yoksa farklı olan ilk grup. Anahtar zaten ekranda gösterildi;
  /// karşılaştırma yalnızca yol gösterir, asıl doğrulama kurtarma yuvası
  /// açılarak yapılır.
  String _mismatchHint(AppLocalizations l10n, String fallback) {
    final shown = _recoveryKeyText;
    if (shown == null) return fallback;
    final typed = RecoveryKeyCodec.symbolsOf(_typedKey.text);
    final expected = RecoveryKeyCodec.symbolsOf(shown);
    if (typed.length != expected.length) {
      return l10n.recoveryKeyLength(typed.length, expected.length);
    }
    const size = RecoveryKeyCodec.groupLength;
    for (var start = 0; start < expected.length; start += size) {
      final end = (start + size).clamp(0, expected.length);
      if (typed.substring(start, end) != expected.substring(start, end)) {
        return l10n.recoveryKeyGroupWrong(start ~/ size + 1);
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KkScaffold(
      appBar: kkRootAppBar(context, title: l10n.setupTitle),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Adım göstergesi dolarak ilerler (madde 4.7).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: ExcludeSemantics(
                child: KeyedSubtree(
                  key: OnboardingScreen.stepIndicatorKey,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_step.index + 1) / _Step.values.length),
                    duration: KkMotion.of(context, KkMotion.enter),
                    curve: KkMotion.standard,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                // Adımlar arası içerik yana kayar.
                child: AnimatedSwitcher(
                  duration: KkMotion.of(context, KkMotion.enter),
                  switchInCurve: KkMotion.standard,
                  switchOutCurve: KkMotion.standard,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(_step);
                    // Kayıp giden adım (ör. kurtarma anahtarı) yalnızca
                    // çizilir: dokunulmaz, odaklanmaz, ekran okuyucu okumaz.
                    return IgnorePointer(
                      ignoring: !incoming,
                      child: ExcludeFocus(
                        excluding: !incoming,
                        child: ExcludeSemantics(
                          excluding: !incoming,
                          child: FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: Offset(incoming ? 0.25 : -0.25, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey(_step),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: switch (_step) {
                      _Step.password => _passwordStep(l10n),
                      _Step.showKey => _showKeyStep(l10n),
                      _Step.verifyKey => _verifyStep(l10n),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _passwordStep(AppLocalizations l10n) {
    return [
      const Center(child: KeyKeyLogo(size: 72)),
      const SizedBox(height: 16),
      Text(l10n.setupIntro),
      const SizedBox(height: 12),
      _WarningCard(text: l10n.setupPasswordWarning),
      const SizedBox(height: 16),
      GlassSurface(
        padding: const EdgeInsets.all(12),
        child: NewPasswordFields(
          password: _password,
          confirmation: _confirmation,
          enabled: !_busy,
          autofocus: true,
          onSubmitted: _create,
        ),
      ),
      if (_error != null) ...[const SizedBox(height: 12), _ErrorText(_error!)],
      const SizedBox(height: 16),
      ListenableBuilder(
        listenable: Listenable.merge([_password, _confirmation]),
        builder: (context, _) => FilledButton(
          onPressed: _canCreate ? _create : null,
          child: Text(_busy ? l10n.setupCreating : l10n.setupCreate),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : () => pickBackupToRestore(context, ref),
        child: Text(l10n.restoreTitle),
      ),
    ];
  }

  /// Anahtarı güvenli panoya kopyalar; pano 30 saniye sonra temizlenir.
  Future<void> _copyKey() async {
    final text = _recoveryKeyText;
    if (text == null) return;
    await copySensitive(context, ref, text);
  }

  /// Anahtarı kullanıcının seçtiği yere metin dosyası olarak kaydeder.
  /// Kurulum sırasında arka plan kilidi çalışmadığı için seçici kapıdan
  /// geçmez (guvenlik-tasarimi.md, Kasa oluşturma).
  Future<void> _saveKeyFile() async {
    final text = _recoveryKeyText;
    if (text == null) return;
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final result = await ref
        .read(documentFilesProvider)
        .save(
          suggestedName: l10n.recoveryFileName,
          mimeType: 'text/plain',
          bytes: utf8.encode('${l10n.recoveryFileHeader}\n$text\n'),
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

  /// Kaydedilmiş dosyadan anahtarı okuyup kutuya yazar. Anahtar,
  /// karakterleri tam bir anahtar uzunluğunda olan ilk satırdır.
  Future<void> _readKeyFile() async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final result = await ref
        .read(documentFilesProvider)
        .open(mimeTypes: const ['text/plain'], maxBytes: 4096);
    if (result is DocumentOpenCancelled) return;
    String? line;
    if (result is DocumentOpened) {
      final text = utf8.decode(result.bytes, allowMalformed: true);
      result.bytes.fillRange(0, result.bytes.length, 0);
      for (final candidate in const LineSplitter().convert(text)) {
        if (RecoveryKeyCodec.symbolsOf(candidate).length ==
            RecoveryKeyCodec.textLength) {
          line = candidate;
          break;
        }
      }
    }
    if (!mounted) return;
    if (line == null) {
      snack(l10n.recoveryFileNoKey);
      return;
    }
    _typedKey.value = RecoveryKeyFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: line.trim()),
    );
    setState(() => _error = null);
  }

  List<Widget> _showKeyStep(AppLocalizations l10n) {
    return [
      Text(l10n.recoveryShowIntro),
      const SizedBox(height: 12),
      _WarningCard(text: l10n.recoveryShowWarning),
      const SizedBox(height: 16),
      GlassSurface(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _recoveryKeyText ?? '',
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
          TextButton.icon(
            onPressed: _copyKey,
            icon: const Icon(Icons.copy_rounded),
            label: Text(l10n.recoveryCopy),
          ),
          TextButton.icon(
            onPressed: _saveKeyFile,
            icon: const Icon(Icons.save_alt_rounded),
            label: Text(l10n.recoverySaveFile),
          ),
        ],
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () => setState(() {
          _step = _Step.verifyKey;
          _error = null;
        }),
        child: Text(l10n.recoveryShowContinue),
      ),
    ];
  }

  List<Widget> _verifyStep(AppLocalizations l10n) {
    return [
      Text(l10n.recoveryVerifyIntro),
      const SizedBox(height: 16),
      GlassSurface(
        padding: const EdgeInsets.all(4),
        child: SecretField(
          controller: _typedKey,
          label: l10n.recoveryKeyLabel,
          obscure: false,
          autofocus: true,
          enabled: !_busy,
          errorText: _error,
          helperText: l10n.recoveryKeyProgress(
            RecoveryKeyCodec.symbolsOf(_typedKey.text).length,
            RecoveryKeyCodec.textLength,
          ),
          // Tireler kendiliğinden gelir; uzun anahtar satıra sığmazsa alta
          // geçer.
          inputFormatters: [RecoveryKeyFormatter()],
          style: const TextStyle(fontFamily: 'monospace'),
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _verify(),
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          onPressed: _busy ? null : _readKeyFile,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(l10n.recoveryReadFile),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _busy ? null : _verify,
        child: Text(l10n.recoveryVerifyConfirm),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _step = _Step.showKey;
                _error = null;
              }),
        child: Text(l10n.recoveryVerifyBack),
      ),
    ];
  }
}

class _WarningCard extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Opak: uyarının okunurluğu zemine bağlı kalmasın.
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

class _ErrorText extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
