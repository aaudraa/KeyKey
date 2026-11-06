import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/recovery_key_formatter.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ana parola unutulunca kurtarma anahtarıyla giriş.
class RecoveryScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _key = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _submit() {
    if (_key.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final count = RecoveryKeyCodec.symbolsOf(_key.text).length;
    if (count != RecoveryKeyCodec.textLength) {
      setState(
        () =>
            _error = l10n.recoveryKeyLength(count, RecoveryKeyCodec.textLength),
      );
      return;
    }
    try {
      ref
          .read(vaultControllerProvider.notifier)
          .unlockWithRecoveryKey(_key.text);
    } on InvalidRecoveryKeyException {
      setState(() => _error = l10n.recoveryKeyInvalid);
    } on WrongSecretException {
      setState(() => _error = l10n.recoveryKeyWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoveryTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.recoveryIntro),
              const SizedBox(height: 16),
              SecretField(
                controller: _key,
                label: l10n.recoveryKeyLabel,
                obscure: false,
                autofocus: true,
                errorText: _error,
                helperText: l10n.recoveryKeyProgress(
                  RecoveryKeyCodec.symbolsOf(_key.text).length,
                  RecoveryKeyCodec.textLength,
                ),
                inputFormatters: [RecoveryKeyFormatter()],
                style: const TextStyle(fontFamily: 'monospace'),
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: Text(l10n.recoverySubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
