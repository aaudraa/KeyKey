import 'package:flutter/material.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/vault/password_policy.dart';
import 'package:keykey/features/generator/presentation/password_strength_meter.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Yeni ana parola: iki kutu ve güç göstergesi.
///
/// Kasa kurulumu, kurtarma ve parola değiştirme aynı kuralları kullanır.
class NewPasswordFields extends StatefulWidget {
  const new({
    required this.password,
    required this.confirmation,
    required this.enabled,
    this.autofocus = false,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController password;
  final TextEditingController confirmation;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  /// İki kutu kuralları sağlıyorsa `true`.
  static bool isValid(String password, String confirmation) =>
      PasswordPolicy.isAcceptable(password) && password == confirmation;

  @override
  State<NewPasswordFields> createState() => _NewPasswordFieldsState();
}

class _NewPasswordFieldsState extends State<NewPasswordFields> {
  void _changed(String _) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final password = widget.password.text;
    final confirmation = widget.confirmation.text;
    final mismatch = confirmation.isNotEmpty && password != confirmation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecretField(
          controller: widget.password,
          label: l10n.newPasswordLabel,
          helperText: l10n.newPasswordHelper(PasswordPolicy.minLength),
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
          onChanged: _changed,
        ),
        const SizedBox(height: 8),
        PasswordStrengthMeter(password: password),
        const SizedBox(height: 16),
        SecretField(
          controller: widget.confirmation,
          label: l10n.confirmPasswordLabel,
          errorText: mismatch ? l10n.confirmPasswordMismatch : null,
          enabled: widget.enabled,
          onChanged: _changed,
          onSubmitted: (_) => widget.onSubmitted?.call(),
        ),
      ],
    );
  }
}
