import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:keykey/features/backup/presentation/restore_screen.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/new_password_fields.dart';
import 'package:keykey/features/lock/presentation/recovery_key_formatter.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

enum _Step { password, showKey, verifyKey }

/// Kasa oluşturma. Kurtarma anahtarı doğrulanana kadar diske bir şey yazılmaz.
class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: switch (_step) {
              _Step.password => _passwordStep(l10n),
              _Step.showKey => _showKeyStep(l10n),
              _Step.verifyKey => _verifyStep(l10n),
            },
          ),
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
      NewPasswordFields(
        password: _password,
        confirmation: _confirmation,
        enabled: !_busy,
        autofocus: true,
        onSubmitted: _create,
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

  List<Widget> _showKeyStep(AppLocalizations l10n) {
    return [
      Text(l10n.recoveryShowIntro),
      const SizedBox(height: 12),
      _WarningCard(text: l10n.recoveryShowWarning),
      const SizedBox(height: 16),
      Card(
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
      const SizedBox(height: 16),
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
      SecretField(
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
        // Tireler kendiliğinden gelir; uzun anahtar satıra sığmazsa alta geçer.
        inputFormatters: [RecoveryKeyFormatter()],
        style: const TextStyle(fontFamily: 'monospace'),
        maxLines: 3,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _verify(),
      ),
      const SizedBox(height: 16),
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
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
