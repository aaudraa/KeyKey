import 'package:flutter/material.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ana parola ve kurtarma anahtarı için metin kutusu.
///
/// Klavye öğrenmesi ve otomatik düzeltme kapalıdır, böylece yazılan metin
/// klavyenin sözlüğüne girmez.
class SecretField extends StatefulWidget {
  const new({
    required this.controller,
    required this.label,
    this.obscure = true,
    this.errorText,
    this.helperText,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  /// `true` ise metin gizlenir ve göster düğmesi çıkar.
  final bool obscure;
  final String? errorText;
  final String? helperText;
  final bool autofocus;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      // Kapatmak yerine salt okunur: odak ve klavye korunur, kullanıcı yanlış
      // paroladan sonra kutuya yeniden dokunmak zorunda kalmaz.
      readOnly: !widget.enabled,
      obscureText: widget.obscure && !_visible,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        helperText: widget.helperText,
        helperMaxLines: 3,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _visible ? l10n.secretHide : l10n.secretShow,
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              )
            : null,
      ),
    );
  }
}
