import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/autofill/application/autofill_setup.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ayarlar ekranında otomatik doldurmanın durumu ve kurulum bağlantıları.
///
/// Durum ekran açılınca ve uygulamaya dönülünce yeniden okunur. Okunamazsa
/// bölüm görünmez.
class AutofillSetupSection extends ConsumerStatefulWidget {
  const new({super.key});

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
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    if (!status.supported) {
      return ListTile(
        enabled: false,
        leading: const Icon(Icons.edit_note),
        title: Text(l10n.autofillSetupTitle),
        subtitle: Text(l10n.autofillSetupUnsupported),
      );
    }
    final chromeVersion = status.chromeMajorVersion;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.edit_note),
          title: Text(l10n.autofillSetupTitle),
          subtitle: Text(
            status.enabled
                ? l10n.autofillSetupEnabled
                : l10n.autofillSetupDisabled,
          ),
          trailing: Icon(
            status.enabled ? Icons.check_circle : Icons.open_in_new,
          ),
          onTap: () => unawaited(_open((b) => b.openAutofillSettings())),
        ),
        if (chromeVersion != null)
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(l10n.autofillSetupChromeTitle),
            subtitle: Text(
              status.chromeTooOld
                  ? l10n.autofillSetupChromeUpdate(chromeVersion)
                  : l10n.autofillSetupChrome,
            ),
            trailing: status.chromeTooOld
                ? null
                : const Icon(Icons.open_in_new),
            onTap: status.chromeTooOld
                ? null
                : () => unawaited(_open((b) => b.openChromeAutofillSettings())),
          ),
      ],
    );
  }
}
