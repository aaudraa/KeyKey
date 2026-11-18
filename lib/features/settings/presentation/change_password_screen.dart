import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/backup/application/auto_backup_controller.dart';
import 'package:keykey/features/backup/presentation/backup_section.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/new_password_fields.dart';
import 'package:keykey/features/lock/presentation/wait_countdown.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ana parola değiştirme. Mevcut parola yeniden sorulur.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;

  /// Parola değişti; alanlardaki eski parola bir daha gönderilmez.
  bool _changed = false;
  String? _error;

  /// Yanlış parolalardan sonra kalan bekleme; kilit ekranındaki sayaçla aynı.
  Duration _wait = Duration.zero;
  late final _countdown = WaitCountdown((left) => setState(() => _wait = left));

  @override
  void dispose() {
    _countdown.dispose();
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _startWait(Duration wait) => _countdown.start(wait);

  bool get _canSubmit =>
      !_busy &&
      !_changed &&
      _wait == Duration.zero &&
      _current.text.isNotEmpty &&
      NewPasswordFields.isValid(_password.text, _confirmation.text);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    // Ekrandan çıkılsa da kullanılabilsin diye önceden alınır.
    final autoBackup = ref.read(autoBackupControllerProvider.notifier);
    try {
      final attempt = await ref
          .read(vaultControllerProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _password.text,
          );
      // En yeni otomatik yedek yeni parolayla açılsın; kapalıysa bir şey
      // yapmaz. Kullanıcı bu sırada ekrandan çıkmış olabilir.
      if (attempt is PasswordAccepted) {
        unawaited(autoBackup.backUpNowOrOnOpen());
      }
      if (!mounted) return;
      switch (attempt) {
        case PasswordAccepted():
          // Parola değişti; not açıkken düğme dönmesin.
          setState(() {
            _busy = false;
            _changed = true;
          });
          // Eski yedekler eski parolayla açılır (bilinen sınır 5).
          final backUp = await showKkConfirm(
            context,
            title: l10n.changePasswordDone,
            message: l10n.changePasswordBackupNote,
            confirmLabel: l10n.changePasswordBackupNow,
            cancelLabel: l10n.changePasswordBackupLater,
          );
          // Not açıkken kasa kilitlendiyse kilit ekranındayız.
          if (!mounted || ref.read(vaultControllerProvider) is! VaultOpen) {
            return;
          }
          if (backUp) {
            await backUpVault(context, ref);
          } else {
            snack(l10n.changePasswordDone);
          }
          if (mounted) context.pop();
        case PasswordInterrupted():
          break;
        case PasswordRejected(:final wait):
          _current.clear();
          setState(() => _error = l10n.lockWrongPassword);
          _startWait(wait);
        case PasswordMustWait(:final wait):
          _startWait(wait);
      }
    } on Exception {
      if (mounted) setState(() => _error = l10n.setupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.changePasswordTitle),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_current, _password, _confirmation]),
        builder: (context, _) => KkBottomAction(
          label: l10n.changePasswordSave,
          busy: _busy,
          onPressed: _canSubmit ? _submit : null,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KkFieldCard(
              child: SecretField(
                controller: _current,
                label: l10n.changePasswordCurrent,
                autofocus: true,
                enabled: !_busy,
                errorText: _wait > Duration.zero
                    ? l10n.lockWait(formatWait(_wait))
                    : _error,
                textInputAction: TextInputAction.next,
              ),
            ),
            GlassSurface(
              padding: const EdgeInsets.all(12),
              child: NewPasswordFields(
                password: _password,
                confirmation: _confirmation,
                enabled: !_busy,
                onSubmitted: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
