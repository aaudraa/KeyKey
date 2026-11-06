import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kasa açıkken kimliği yeniden doğrular: parmak izi açıksa önce o, sonra
/// ana parola. Doğrulandıysa `true`.
Future<bool> confirmIdentity(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final vault = ref.read(vaultControllerProvider.notifier);
  try {
    if (await vault.isBiometricUsable()) {
      final outcome = await vault.confirmBiometric(
        BiometricTexts(
          title: l10n.otpConfirmTitle,
          negativeButton: l10n.biometricUseMasterPassword,
        ),
      );
      if (outcome is BiometricSuccess) return true;
      // Vazgeçildi veya parmak izi kullanılamadı: ana parola sorulur.
    }
  } on VaultLockedException {
    return false;
  }
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => const _PasswordDialog(),
  );
  return confirmed ?? false;
}

class _PasswordDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _password.text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final attempt = await ref
          .read(vaultControllerProvider.notifier)
          .confirmPassword(_password.text);
      if (!mounted) return;
      switch (attempt) {
        case PasswordAccepted():
          _password.clear();
          Navigator.pop(context, true);
        case PasswordRejected(:final wait):
          _password.clear();
          setState(
            () => _error = wait > Duration.zero
                ? l10n.lockWait(_formatWait(wait))
                : l10n.lockWrongPassword,
          );
        case PasswordMustWait(:final wait):
          setState(() => _error = l10n.lockWait(_formatWait(wait)));
        case PasswordInterrupted():
          Navigator.pop(context, false);
      }
    } on VaultLockedException {
      if (mounted) Navigator.pop(context, false);
    } on Exception {
      if (mounted) setState(() => _error = l10n.lockFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _formatWait(Duration wait) {
    final minutes = wait.inMinutes;
    final seconds = wait.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.otpConfirmTitle),
      content: SecretField(
        controller: _password,
        label: l10n.lockPasswordLabel,
        autofocus: true,
        enabled: !_busy,
        errorText: _error,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.biometricCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.otpConfirmButton),
        ),
      ],
    );
  }
}
