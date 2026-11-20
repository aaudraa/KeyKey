import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/network/secure_url.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_controller.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:keykey/features/sync/presentation/sync_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Senkron kapalıyken: klasör adresi, kullanıcı adı ve uygulama parolası.
/// **Bağlan** klasörü denetler; ancak boşsa ya da bu kasanınsa, açıklama
/// penceresinden sonra senkron açılır. Tasarım: `resources/docs/senkron.md`,
/// "Senkronu açmak".
class SyncSetupForm extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SyncSetupForm> createState() => _SyncSetupFormState();
}

class _SyncSetupFormState extends ConsumerState<SyncSetupForm> {
  final _folder = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _folderError;
  String? _error;

  @override
  void dispose() {
    _folder.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      _folder.text.trim().isNotEmpty &&
      _username.text.isNotEmpty &&
      _password.text.isNotEmpty;

  Future<void> _connect() async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(_folder.text.trim());
    if (uri == null || !isSecureServiceUrl(uri)) {
      setState(() {
        _folderError = l10n.syncFolderInvalid;
        _error = null;
      });
      return;
    }
    final vault = ref.read(vaultControllerProvider);
    if (vault is! VaultOpen) return;
    final settings = SyncSettings(
      folder: uri,
      username: _username.text,
      appPassword: _password.text,
    );
    setState(() {
      _busy = true;
      _folderError = null;
      _error = null;
    });
    final FolderState folder;
    try {
      folder = await ref
          .read(syncServiceProvider)
          .inspect(settings, vault.session.header.vaultId);
    } on SyncTransportException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = syncFailureText(l10n, error.kind);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (folder) {
      case FolderEmpty() || FolderSameVault():
        await _confirmAndEnable(settings);
      case FolderOtherVault():
        await showSyncInfo(
          context,
          title: l10n.syncOtherVaultTitle,
          message: l10n.syncOtherVaultBody,
          button: l10n.syncCancel,
        );
      case FolderMixedVaults():
        await showSyncInfo(
          context,
          title: l10n.syncMixedTitle,
          message: l10n.syncMixedBody,
        );
    }
  }

  Future<void> _confirmAndEnable(SyncSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final confirmed = await showKkConfirm(
      context,
      title: l10n.syncConfirmTitle,
      message: l10n.syncConfirmBody,
      confirmLabel: l10n.syncConfirmOn,
      cancelLabel: l10n.syncCancel,
    );
    if (!confirmed || !mounted) return;
    // Ekrandan çıkılsa da kullanılabilsin diye önceden alınır.
    final controller = ref.read(syncControllerProvider.notifier);
    try {
      await ref.read(settingsControllerProvider.notifier).setSync(settings);
    } on VaultLockedException {
      return;
    }
    snack(l10n.syncEnabled);
    final status = await controller.syncNow();
    final error = syncStatusError(l10n, status);
    if (error != null) snack(error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.syncTitle),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_folder, _username, _password]),
        builder: (context, _) => KkBottomAction(
          label: l10n.syncConnect,
          busy: _busy,
          onPressed: _canSubmit ? _connect : null,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSurface(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.syncIntro, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 12),
            KkFieldCard(
              child: SecretField(
                controller: _folder,
                label: l10n.syncFolderLabel,
                obscure: false,
                plain: PlainKeyboard.url,
                enabled: !_busy,
                helperText: l10n.syncFolderHelp,
                errorText: _folderError,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_folderError != null) {
                    setState(() => _folderError = null);
                  }
                },
              ),
            ),
            KkFieldCard(
              child: SecretField(
                controller: _username,
                label: l10n.syncUsernameLabel,
                obscure: false,
                plain: PlainKeyboard.text,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
              ),
            ),
            KkFieldCard(
              child: SecretField(
                controller: _password,
                label: l10n.syncAppPasswordLabel,
                enabled: !_busy,
                helperText: l10n.syncAppPasswordHelp,
                errorText: _error,
                onSubmitted: (_) => unawaited(_connect()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
