import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/network/secure_url.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/presentation/restore_screen.dart';
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
///
/// [newPhone] ise kasası olmayan telefondadır ("Yeni telefon"): klasörde tek
/// kasa varsa en yeni dosyası geri yükleme ekranında açılır.
class SyncSetupForm extends ConsumerStatefulWidget {
  const new({this.newPhone = false, super.key});

  final bool newPhone;

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
    final Uint8List? vaultId;
    switch (vault) {
      case VaultOpen(:final session) when !widget.newPhone:
        vaultId = session.header.vaultId;
      case VaultNotSetUp() when widget.newPhone:
        vaultId = null;
      default:
        return;
    }
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
      folder = await ref.read(syncServiceProvider).inspect(settings, vaultId);
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
    if (widget.newPhone) return await _setUpFrom(folder, settings);
    switch (folder) {
      case FolderEmpty() || FolderSameVault():
        await _confirmAndEnable(settings);
      case FolderOtherVault(:final newest):
        await _offerJoin(newest, settings);
      case FolderMixedVaults():
        await showSyncInfo(
          context,
          title: l10n.syncMixedTitle,
          message: l10n.syncMixedBody,
        );
    }
  }

  /// Klasörde başka kasa var: bu telefon o kasaya katılabilir. Önce
  /// seçenek, sonra ana parolanın değişeceği uyarısı; vazgeçilirse bir şey
  /// yazılmaz.
  Future<void> _offerJoin(BackupFile newest, SyncSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final join = await showKkConfirm(
      context,
      title: l10n.syncOtherVaultTitle,
      message: l10n.syncOtherVaultBody,
      confirmLabel: l10n.syncJoinButton,
      cancelLabel: l10n.syncCancel,
    );
    if (!join || !mounted) return;
    final confirmed = await showKkConfirm(
      context,
      title: l10n.syncJoinWarnTitle,
      message: l10n.syncJoinWarnBody,
      confirmLabel: l10n.syncJoinConfirm,
      cancelLabel: l10n.syncCancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.push(
      AppRoutes.syncJoin,
      extra: SyncRestoreRequest(file: newest, sync: settings),
    );
  }

  Future<void> _setUpFrom(FolderState folder, SyncSettings settings) async {
    final l10n = AppLocalizations.of(context);
    switch (folder) {
      case FolderEmpty() || FolderSameVault():
        setState(() => _error = l10n.syncNoFiles);
      case FolderOtherVault(:final newest):
        await context.push(
          AppRoutes.restore,
          extra: SyncRestoreRequest(file: newest, sync: settings),
        );
      case FolderMixedVaults():
        await showSyncInfo(
          context,
          title: l10n.syncMixedTitle,
          message: l10n.syncMixedSetupBody,
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
      appBar: kkAppBar(
        context,
        title: widget.newPhone ? l10n.setupFromSync : l10n.syncTitle,
      ),
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
              child: Text(
                widget.newPhone ? l10n.syncSetupIntro : l10n.syncIntro,
                style: theme.textTheme.bodyMedium,
              ),
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
