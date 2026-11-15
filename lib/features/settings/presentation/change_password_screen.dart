import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/new_password_fields.dart';
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
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      _current.text.isNotEmpty &&
      NewPasswordFields.isValid(_password.text, _confirmation.text);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final attempt = await ref
          .read(vaultControllerProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      switch (attempt) {
        case PasswordAccepted():
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.changePasswordDone)),
          );
          context.pop();
        case PasswordInterrupted():
          break;
        case PasswordRejected():
          _current.clear();
          setState(() => _error = l10n.lockWrongPassword);
        case PasswordMustWait(:final wait):
          setState(() => _error = l10n.changePasswordWait(wait.inSeconds));
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
                errorText: _error,
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
