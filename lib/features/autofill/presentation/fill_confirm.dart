import 'package:flutter/material.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/fill_warnings.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/cert_fingerprint.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kullanıcının uyarıları okuyup doldurmayı onayladığı içerik. Doldurmanın
/// yarım penceresinde, listenin yerinde gösterilir.
///
/// Vazgeçilirse [onCancel], onaylanırsa uygulamanın kayda bağlanıp
/// bağlanmayacağıyla [onConfirm] çağrılır.
class FillConfirmContent extends StatefulWidget {
  const new({
    required this.target,
    required this.item,
    required this.warnings,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  final AutofillTarget target;
  final LoginItem item;
  final Set<FillWarning> warnings;
  final VoidCallback onCancel;
  final void Function({required bool bind}) onConfirm;

  @override
  State<FillConfirmContent> createState() => _FillConfirmContentState();
}

class _FillConfirmContentState extends State<FillConfirmContent> {
  bool _bind = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final target = widget.target;
    final warnings = widget.warnings;
    final danger = warnings.contains(FillWarning.signatureMismatch);
    final appName = target.appLabel ?? target.packageName;
    final bindable = canBindApp(target: target, warnings: warnings);

    final reasons = <String>[
      if (danger) l10n.autofillWarnSignature(target.packageName),
      if (warnings.contains(FillWarning.noMatch))
        if (target.isWeb)
          l10n.autofillWarnNoMatchWeb(target.webDomain!)
        else
          l10n.autofillWarnNoMatchApp(appName),
      if (warnings.contains(FillWarning.webView))
        switch (target.untrustedWebDomain) {
          final domain? => l10n.autofillWarnWebView(domain),
          null => l10n.autofillWarnWebViewUnknown,
        },
      if (warnings.contains(FillWarning.insecure)) l10n.autofillWarnInsecure,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Icon(
                danger ? Icons.gpp_bad_outlined : Icons.warning_amber_rounded,
                color: danger ? theme.colorScheme.error : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    danger
                        ? l10n.autofillWarnSignatureTitle
                        : l10n.autofillWarnTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reason in reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(reason),
                  ),
                Text(
                  l10n.autofillWarnLogin(
                    widget.item.content.name.isEmpty
                        ? '—'
                        : widget.item.content.name,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Tarayıcıda uygulama bilgisi işe yaramaz; adres çubuğu yeter.
                if (!target.isWeb) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    [
                      l10n.autofillAppName(appName),
                      l10n.autofillAppPackage(target.packageName),
                      for (final cert in target.certsSha256)
                        l10n.autofillAppSignature(formatCertFingerprint(cert)),
                    ].join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (bindable) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _bind,
                    onChanged: (value) =>
                        setState(() => _bind = value ?? false),
                    title: Text(l10n.autofillBindApp),
                    subtitle: Text(l10n.autofillBindAppHint),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(l10n.autofillCancel),
              ),
              FilledButton(
                style: danger
                    ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      )
                    : null,
                onPressed: () => widget.onConfirm(bind: _bind),
                child: Text(l10n.autofillFillAnyway),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
