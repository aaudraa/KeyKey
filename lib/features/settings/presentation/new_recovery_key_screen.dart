import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/auto_backup_controller.dart';
import 'package:keykey/features/backup/presentation/backup_section.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/recovery_key_steps.dart';
import 'package:keykey/features/lock/presentation/wait_countdown.dart';
import 'package:keykey/features/settings/application/recovery_renewal_notice.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Yeni kurtarma anahtarı: ana parola, yeni anahtarı gösterme, geri yazarak
/// doğrulama. Tasarım: `resources/docs/kurtarma-anahtari-yenileme.md`.
///
/// Anahtar doğrulanana kadar diske bir şey yazılmaz; ekrandan çıkılırsa ya da
/// kasa kilitlenirse kasa eski anahtarla kalır.
class NewRecoveryKeyScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NewRecoveryKeyScreen> createState() =>
      _NewRecoveryKeyScreenState();
}

enum _Step { password, showKey, verifyKey }

class _NewRecoveryKeyScreenState extends ConsumerState<NewRecoveryKeyScreen> {
  final _password = TextEditingController();
  final _typedKey = TextEditingController();

  _Step _step = _Step.password;
  PendingRecoveryKey? _pending;
  bool _busy = false;
  String? _error;

  /// Yeni anahtar kaydedildi; ekran artık sormadan kapanır.
  bool _saved = false;

  /// Doğrulama sürüyor: kilit bu sırada gelirse sonuç yazmanın bitip
  /// bitmediğine bağlı, işareti doğrulamanın sonucu koyar.
  bool _confirming = false;
  bool _lockedWhileConfirming = false;
  late final VaultController _vault;
  late final RecoveryRenewalInterrupted _interrupted;

  @override
  void initState() {
    super.initState();
    _vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_onLock);
    _interrupted = ref.read(recoveryRenewalInterruptedProvider.notifier);
  }

  /// Kilitte yeni anahtar bellekten bırakılır. Anahtar gösterilmiş ama
  /// doğrulanmamışsa kilit açılınca kullanıcıya söylenir: not aldığı anahtar
  /// geçersiz, eskisi geçerli.
  void _onLock() {
    if (_confirming) {
      _lockedWhileConfirming = true;
    } else if (_pending != null) {
      _interrupted.mark();
    }
    _pending = null;
    _password.clear();
    _typedKey.clear();
  }

  /// Yanlış parolalardan sonra kalan bekleme; kilit ekranındaki sayaçla aynı.
  Duration _wait = Duration.zero;
  late final _countdown = WaitCountdown((left) => setState(() => _wait = left));

  @override
  void dispose() {
    _vault.removeLockListener(_onLock);
    _countdown.dispose();
    _password.dispose();
    _typedKey.dispose();
    super.dispose();
  }

  bool get _canCheck =>
      !_busy && _wait == Duration.zero && _password.text.isNotEmpty;

  Future<void> _check() async {
    if (!_canCheck) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (attempt, pending) = await ref
          .read(vaultControllerProvider.notifier)
          .prepareNewRecoveryKey(_password.text);
      if (!mounted) return;
      switch (attempt) {
        case PasswordAccepted():
          _password.clear();
          setState(() {
            _pending = pending;
            _step = _Step.showKey;
          });
        case PasswordInterrupted():
          break;
        case PasswordRejected(:final wait):
          _password.clear();
          setState(() => _error = l10n.lockWrongPassword);
          _countdown.start(wait);
        case PasswordMustWait(:final wait):
          _countdown.start(wait);
      }
    } on Exception {
      if (mounted) setState(() => _error = l10n.setupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final pending = _pending;
    if (_busy || pending == null || _typedKey.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    // Ekrandan çıkılsa da kullanılabilsin diye önceden alınır.
    final autoBackup = ref.read(autoBackupControllerProvider.notifier);
    setState(() {
      _busy = true;
      _error = null;
    });
    _confirming = true;
    _lockedWhileConfirming = false;
    try {
      await _vault.confirmNewRecoveryKey(pending, _typedKey.text);
      _confirming = false;
      _saved = true;
      // En yeni otomatik yedek yeni anahtarla açılsın; bu sırada kilitlendiyse
      // kasa açılınca yazılır. Kapalıysa bir şey yapmaz.
      unawaited(autoBackup.backUpNowOrOnOpen());
      if (!mounted) return;
      setState(() => _busy = false);
      final backUp = await showKkConfirm(
        context,
        title: l10n.newRecoveryDone,
        message: l10n.newRecoveryBackupNote,
        confirmLabel: l10n.changePasswordBackupNow,
        cancelLabel: l10n.changePasswordBackupLater,
      );
      // Not açıkken kasa kilitlendiyse kilit ekranındayız.
      if (!mounted || ref.read(vaultControllerProvider) is! VaultOpen) return;
      if (backUp) {
        await backUpVault(context, ref);
      } else {
        snack(l10n.newRecoveryDone);
      }
      if (mounted) context.pop();
    } on InvalidRecoveryKeyException {
      _showMismatch(l10n, l10n.recoveryKeyInvalid);
    } on WrongSecretException {
      _showMismatch(l10n, l10n.recoveryKeyWrong);
    } on VaultLockedException {
      // Kasa yazmadan önce kilitlendi; yeni anahtar kaydedilmedi.
      _interrupted.mark();
    } on Exception {
      if (mounted) setState(() => _error = l10n.setupFailed);
    } finally {
      // Yazmadan önce bir hata olduysa ve bu arada kilitlendiyse anahtar
      // kaydedilmedi.
      if (_confirming && _lockedWhileConfirming) _interrupted.mark();
      _confirming = false;
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  void _showMismatch(AppLocalizations l10n, String fallback) {
    if (!mounted) return;
    setState(
      () => _error = recoveryKeyMismatchHint(
        l10n,
        shown: _pending?.recoveryKeyText,
        typed: _typedKey.text,
        fallback: fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Doğrulama sürerken çıkılmaz: yazma bitince sonuç ekranda söylenir.
    // Anahtar gösterildiyse çıkmadan önce sorulur: not alınan anahtar
    // doğrulanmadan geçerli olmaz.
    final unsaved = _pending != null && !_saved;
    return PopScope(
      canPop: !_busy && !unsaved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy || !unsaved) return;
        final leave = await showKkConfirm(
          context,
          title: l10n.newRecoveryLeaveTitle,
          message: l10n.newRecoveryLeaveBody,
          confirmLabel: l10n.newRecoveryLeave,
          cancelLabel: l10n.newRecoveryStay,
          destructive: true,
        );
        if (!leave || !mounted) return;
        setState(() => _pending = null);
        this.context.pop();
      },
      child: _scaffold(l10n),
    );
  }

  Widget _scaffold(AppLocalizations l10n) {
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.newRecoveryTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          key: ValueKey(_step),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (_step) {
            _Step.password => _passwordStep(l10n),
            _Step.showKey => _showKeyStep(l10n),
            _Step.verifyKey => _verifyStep(l10n),
          },
        ),
      ),
    );
  }

  List<Widget> _passwordStep(AppLocalizations l10n) => [
    Text(l10n.newRecoveryIntro),
    const SizedBox(height: 12),
    RecoveryWarningCard(text: l10n.newRecoveryWarning),
    const SizedBox(height: 16),
    KkFieldCard(
      child: SecretField(
        controller: _password,
        label: l10n.changePasswordCurrent,
        autofocus: true,
        enabled: !_busy,
        errorText: _wait > Duration.zero
            ? l10n.lockWait(formatWait(_wait))
            : _error,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _check(),
      ),
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _canCheck ? _check : null,
      child: Text(_busy ? l10n.newRecoveryChecking : l10n.newRecoveryContinue),
    ),
  ];

  List<Widget> _showKeyStep(AppLocalizations l10n) => [
    Text(l10n.recoveryShowIntro),
    const SizedBox(height: 12),
    RecoveryWarningCard(text: l10n.newRecoveryShowWarning),
    const SizedBox(height: 16),
    // Kopyalayıp başka uygulamaya geçmek kasayı kilitler ve yenilemeyi iptal
    // eder; kâğıt ya da kapıdan geçen dosya kaydı kalır.
    RecoveryKeyCard(
      text: _pending?.recoveryKeyText ?? '',
      gated: true,
      allowCopy: false,
    ),
    const SizedBox(height: 8),
    FilledButton(
      onPressed: () => setState(() {
        _step = _Step.verifyKey;
        _error = null;
      }),
      child: Text(l10n.recoveryShowContinue),
    ),
  ];

  List<Widget> _verifyStep(AppLocalizations l10n) => [
    Text(l10n.recoveryVerifyIntro),
    const SizedBox(height: 16),
    RecoveryKeyEntry(
      controller: _typedKey,
      enabled: !_busy,
      gated: true,
      errorText: _error,
      onChanged: () => setState(() {}),
      onRead: () => setState(() => _error = null),
      onSubmitted: _save,
    ),
    const SizedBox(height: 8),
    FilledButton(
      onPressed: _busy ? null : _save,
      child: Text(l10n.newRecoverySave),
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: _busy
          ? null
          : () => setState(() {
              _step = _Step.showKey;
              _error = null;
            }),
      child: Text(l10n.recoveryVerifyBack),
    ),
  ];
}
