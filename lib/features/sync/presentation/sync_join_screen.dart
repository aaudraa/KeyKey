import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/features/lock/application/recovery_key_text.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/recovery_key_formatter.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_join.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Bu telefonu klasördeki kasaya katar: o kasanın ana parolası ya da
/// kurtarma anahtarı istenir. Uyarı bu ekrana gelmeden gösterilir.
class SyncJoinScreen extends ConsumerStatefulWidget {
  const new({required this.file, required this.sync, super.key});

  /// Klasördeki en yeni dosya.
  final BackupFile file;
  final SyncSettings sync;

  @override
  ConsumerState<SyncJoinScreen> createState() => _SyncJoinScreenState();
}

class _SyncJoinScreenState extends ConsumerState<SyncJoinScreen> {
  final _secret = TextEditingController();
  bool _useRecoveryKey = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy || _secret.text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final controller = ref.read(vaultControllerProvider.notifier);
    final vault = ref.read(vaultControllerProvider);
    if (vault is! VaultOpen) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(syncJoinProvider)
          .join(
            current: vault.session,
            remote: widget.file,
            secret: _secret.text,
            isRecoveryKey: _useRecoveryKey,
            settings: widget.sync,
          );
      _secret.clear();
      if (ref.read(vaultControllerProvider) is! VaultOpen) {
        // Katılırken kilitlendi: kasa artık o kasanın parolasıyla açılır.
        final header = session.header;
        session.dispose();
        controller.lockReplaced(header);
        return;
      }
      controller.replaceSession(session);
      snack(l10n.syncJoinDone);
      if (mounted) context.go(AppRoutes.sync);
    } on InvalidRecoveryKeyException {
      _fail(l10n.recoveryKeyInvalid);
    } on WrongSecretException {
      _fail(
        _useRecoveryKey
            ? l10n.syncJoinWrongRecoveryKey
            : l10n.syncJoinWrongPassword,
      );
    } on NewerBackupException {
      _fail(l10n.restoreNewerVersion);
    } on Exception {
      _fail(l10n.syncJoinFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.syncJoinTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.syncJoinIntro),
              const SizedBox(height: 16),
              GlassSurface(
                padding: const EdgeInsets.all(4),
                child: _useRecoveryKey
                    ? SecretField(
                        key: const ValueKey('recovery'),
                        controller: _secret,
                        label: l10n.recoveryKeyLabel,
                        obscure: false,
                        autofocus: true,
                        enabled: !_busy,
                        errorText: _error,
                        helperText: l10n.recoveryKeyProgress(
                          RecoveryKeyText.symbolsOf(_secret.text).length,
                          RecoveryKeyText.textLength,
                        ),
                        inputFormatters: [RecoveryKeyFormatter()],
                        style: const TextStyle(fontFamily: 'monospace'),
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => unawaited(_join()),
                      )
                    : SecretField(
                        key: const ValueKey('password'),
                        controller: _secret,
                        label: l10n.lockPasswordLabel,
                        autofocus: true,
                        enabled: !_busy,
                        errorText: _error,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => unawaited(_join()),
                      ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || _secret.text.isEmpty
                    ? null
                    : () => unawaited(_join()),
                child: Text(l10n.syncJoinSubmit),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _useRecoveryKey = !_useRecoveryKey;
                        _secret.clear();
                        _error = null;
                      }),
                child: Text(
                  _useRecoveryKey
                      ? l10n.restoreUsePassword
                      : l10n.restoreUseRecoveryKey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
