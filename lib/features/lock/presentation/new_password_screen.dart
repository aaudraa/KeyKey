import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/new_password_fields.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kurtarma anahtarıyla girdikten sonra yeni ana parola belirleme.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy && NewPasswordFields.isValid(_password.text, _confirmation.text);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(vaultControllerProvider.notifier)
          .setNewPassword(_password.text);
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
      // Kurtarmada geri dönülmez; yeni parola zorunlu.
      appBar: kkRootAppBar(context, title: l10n.newPasswordTitle),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_password, _confirmation]),
        builder: (context, _) => KkBottomAction(
          label: l10n.newPasswordSave,
          busy: _busy,
          onPressed: _canSubmit ? _submit : null,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.newPasswordIntro),
              const SizedBox(height: 16),
              GlassSurface(
                padding: const EdgeInsets.all(12),
                child: NewPasswordFields(
                  password: _password,
                  confirmation: _confirmation,
                  enabled: !_busy,
                  autofocus: true,
                  onSubmitted: _submit,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
