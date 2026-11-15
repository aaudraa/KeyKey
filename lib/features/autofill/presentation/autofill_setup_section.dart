import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/features/autofill/application/autofill_setup.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ayarlardaki "Otomatik doldurma" grubu: servisin durumu, kurulum
/// bağlantıları ve sonda [children].
///
/// Durum ekran açılınca ve uygulamaya dönülünce yeniden okunur. Okunamazsa
/// durum satırları görünmez, [children] kalır.
class AutofillSetupSection extends ConsumerStatefulWidget {
  const new({this.children = const [], super.key});

  /// Durum satırlarının altına eklenen satırlar.
  final List<Widget> children;

  @override
  ConsumerState<AutofillSetupSection> createState() =>
      _AutofillSetupSectionState();
}

class _AutofillSetupSectionState extends ConsumerState<AutofillSetupSection> {
  AutofillSetupState? _status;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_refresh()));
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    AutofillSetupState? status;
    try {
      status = await ref.read(autofillSetupBridgeProvider).status();
    } on Exception {
      status = null;
    }
    if (mounted) setState(() => _status = status);
  }

  Future<void> _open(Future<bool> Function(AutofillSetupBridge) open) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await open(ref.read(autofillSetupBridgeProvider));
    } on Exception {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.autofillSetupOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KkSection(
      title: l10n.settingsGroupAutofill,
      children: [..._statusRows(l10n), ...widget.children],
    );
  }

  List<Widget> _statusRows(AppLocalizations l10n) {
    final status = _status;
    if (status == null) return const [];
    if (!status.supported) {
      return [
        ListTile(
          enabled: false,
          leading: const KkIconBox(icon: Icons.edit_note_rounded),
          title: Text(l10n.autofillSetupTitle),
          subtitle: KkRowSubtitle(l10n.autofillSetupUnsupported),
        ),
      ];
    }
    final chromeVersion = status.chromeMajorVersion;
    final chromeHelp = chromeVersion == null
        ? null
        : status.chromeTooOld
        ? l10n.autofillSetupChromeUpdate(chromeVersion)
        : l10n.autofillSetupChrome;
    return [
      ListTile(
        leading: const KkIconBox(icon: Icons.edit_note_rounded),
        title: Text(l10n.autofillSetupTitle),
        subtitle: KkRowSubtitle(
          status.enabled
              ? l10n.autofillSetupEnabled
              : l10n.autofillSetupDisabled,
        ),
        trailing: Icon(status.enabled ? Icons.check_circle : Icons.open_in_new),
        onTap: () => unawaited(_open((b) => b.openAutofillSettings())),
      ),
      if (chromeHelp != null)
        ListTile(
          leading: const KkIconBox(icon: Icons.public_rounded),
          title: Text(l10n.autofillSetupChromeTitle),
          subtitle: KkRowSubtitle(chromeHelp),
          contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KkInfoButton(
                title: l10n.autofillSetupChromeTitle,
                info: chromeHelp,
              ),
              if (!status.chromeTooOld) const Icon(Icons.open_in_new),
            ],
          ),
          onTap: status.chromeTooOld
              ? null
              : () => unawaited(_open((b) => b.openChromeAutofillSettings())),
        ),
    ];
  }
}
