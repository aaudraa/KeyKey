import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/features/lock/application/recovery_key_text.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/recovery_key_steps.dart';
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
    final count = RecoveryKeyText.symbolsOf(_key.text).length;
    if (count != RecoveryKeyText.textLength) {
      setState(
        () =>
            _error = l10n.recoveryKeyLength(count, RecoveryKeyText.textLength),
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
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.recoveryTitle),
      bottomNavigationBar: KkBottomAction(
        label: l10n.recoverySubmit,
        onPressed: _submit,
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.recoveryIntro),
              const SizedBox(height: 16),
              // Ortak kutu: anahtarı "Dosyaya kaydet" ile saklayan kullanıcı
              // burada dosyadan okuyabilir. Kasa kilitli; arka plan kilidinin
              // beklemesine gerek yok.
              RecoveryKeyEntry(
                controller: _key,
                enabled: true,
                gated: false,
                errorText: _error,
                onChanged: () => setState(() {}),
                onRead: () => setState(() {}),
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
