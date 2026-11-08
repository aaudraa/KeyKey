import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/recovery_key_formatter.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Belge seçiciyle bir yedek seçtirir, yapısını denetler ve geri yükleme
/// ekranını açar.
Future<void> pickBackupToRestore(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void show(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  final files = ref.read(documentFilesProvider);
  final result = await ref
      .read(externalActivityGateProvider.notifier)
      .run(
        () => files.open(
          mimeTypes: const ['*/*'],
          maxBytes: BackupCodec.maxFileSize,
        ),
      );
  if (!context.mounted) return;
  switch (result) {
    case DocumentOpenCancelled():
      return;
    case DocumentTooLarge():
      show(l10n.restoreTooLarge);
    case DocumentOpenFailed():
      show(l10n.restoreOpenFailed);
    case DocumentOpened(:final bytes):
      final BackupFile file;
      try {
        file = ref.read(restoreServiceProvider).parse(bytes);
      } on InvalidBackupException {
        show(l10n.restoreNotBackup);
        return;
      }
      await context.push(AppRoutes.restore, extra: file);
  }
}

/// Seçilen yedeği açar, özetini gösterir ve kasaya alır.
///
/// Kasa kurulu değilse yedekten yeni kasa kurulur. Açık bir kasada yedek
/// birleştirilir ya da ek onayla kasanın yerine konur.
class RestoreScreen extends ConsumerStatefulWidget {
  const new({required this.file, super.key});

  final BackupFile file;

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  final _secret = TextEditingController();
  bool _useRecoveryKey = false;
  bool _busy = false;
  String? _error;
  OpenedBackup? _opened;

  @override
  void dispose() {
    _opened?.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_busy || _secret.text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final service = ref.read(restoreServiceProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final opened = _useRecoveryKey
          ? await service.openWithRecoveryKey(widget.file, _secret.text)
          : await service.openWithPassword(widget.file, _secret.text);
      if (!mounted) {
        opened.dispose();
        return;
      }
      _secret.clear();
      setState(() => _opened = opened);
    } on InvalidRecoveryKeyException {
      _fail(l10n.recoveryKeyInvalid);
    } on WrongSecretException {
      _fail(
        _useRecoveryKey
            ? l10n.restoreWrongRecoveryKey
            : l10n.restoreWrongPassword,
      );
    } on CorruptedDataException {
      _fail(l10n.restoreCorrupted);
    } on InvalidBackupException {
      _fail(l10n.restoreCorrupted);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  /// Kasa kurulu değilken: yedekten kasa kurulur ve açılır.
  Future<void> _restoreNew(OpenedBackup backup) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(vaultControllerProvider.notifier);
    setState(() => _busy = true);
    try {
      await ref.read(restoreServiceProvider).replace(backup);
      final session = ref
          .read(vaultServiceProvider)
          .openRestoredSession(backup.header, backup.copyKey());
      controller.openRestored(session);
      if (mounted) context.go(AppRoutes.vault);
      messenger.showSnackBar(SnackBar(content: Text(l10n.restoreDone)));
    } on Exception {
      _fail(l10n.restoreFailed);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _merge(OpenedBackup backup, VaultSession session) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final counts = await ref
          .read(restoreServiceProvider)
          .merge(backup, session);
      ref
        ..invalidate(loginsControllerProvider)
        ..invalidate(otpsControllerProvider);
      if (mounted) context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.restoreMerged(counts.added, counts.updated)),
        ),
      );
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on Exception {
      _fail(l10n.restoreFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replace(OpenedBackup backup) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreReplaceConfirmTitle),
        content: Text(l10n.restoreReplaceConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.restoreCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.restoreReplaceConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = ref.read(vaultControllerProvider.notifier);
    setState(() => _busy = true);
    try {
      // Önce parmak izi kapanır: yeni kasanın anahtarı eski yuvayla açılmaz.
      await ref.read(vaultServiceProvider).disableBiometric();
      await ref.read(restoreServiceProvider).replace(backup);
      // Kilit ekranına gidilir; kasa artık yedeğin ana parolasıyla açılır.
      controller.lockReplaced(backup.header);
    } on Exception {
      _fail(l10n.restoreFailed);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final opened = _opened;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.restoreTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: opened == null
                ? _unlockStep(l10n)
                : _summaryStep(l10n, opened),
          ),
        ),
      ),
    );
  }

  List<Widget> _unlockStep(AppLocalizations l10n) {
    return [
      Text(l10n.restoreUnlockIntro),
      const SizedBox(height: 16),
      if (_useRecoveryKey)
        SecretField(
          key: const ValueKey('recovery'),
          controller: _secret,
          label: l10n.recoveryKeyLabel,
          obscure: false,
          autofocus: true,
          enabled: !_busy,
          errorText: _error,
          helperText: l10n.recoveryKeyProgress(
            RecoveryKeyCodec.symbolsOf(_secret.text).length,
            RecoveryKeyCodec.textLength,
          ),
          inputFormatters: [RecoveryKeyFormatter()],
          style: const TextStyle(fontFamily: 'monospace'),
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => unawaited(_open()),
        )
      else
        SecretField(
          key: const ValueKey('password'),
          controller: _secret,
          label: l10n.lockPasswordLabel,
          autofocus: true,
          enabled: !_busy,
          errorText: _error,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => unawaited(_open()),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy || _secret.text.isEmpty
            ? null
            : () => unawaited(_open()),
        child: Text(_busy ? l10n.restoreOpening : l10n.restoreOpen),
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
    ];
  }

  List<Widget> _summaryStep(AppLocalizations l10n, OpenedBackup opened) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale)
        .add_Hm()
        .format(opened.createdAt.toLocal());
    final status = ref.watch(vaultControllerProvider);
    final theme = Theme.of(context);
    return [
      Text(
        l10n.restoreSummary(date, opened.loginCount, opened.otpCount),
        style: theme.textTheme.titleMedium,
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      ],
      const SizedBox(height: 24),
      if (status is VaultOpen) ...[
        Text(l10n.restoreMergeHelp),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy
              ? null
              : () => unawaited(_merge(opened, status.session)),
          child: Text(l10n.restoreMerge),
        ),
        const SizedBox(height: 24),
        Text(l10n.restoreReplaceHelp),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          onPressed: _busy ? null : () => unawaited(_replace(opened)),
          child: Text(l10n.restoreReplace),
        ),
      ] else
        FilledButton(
          onPressed: _busy ? null : () => unawaited(_restoreNew(opened)),
          child: Text(l10n.restoreRestore),
        ),
    ];
  }
}
