import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/features/backup/presentation/restore_screen.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/new_password_fields.dart';
import 'package:keykey/features/lock/presentation/recovery_key_steps.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

enum _Step { password, showKey, verifyKey }

/// Kasa oluşturma. Kurtarma anahtarı doğrulanana kadar diske bir şey yazılmaz.
class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// Adım göstergesi (testler için; madde 4.7).
  static const Key stepIndicatorKey = ValueKey('kk-setup-steps');

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _typedKey = TextEditingController();
  late final VaultController _controller;

  _Step _step = _Step.password;
  String? _recoveryKeyText;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(vaultControllerProvider.notifier);
  }

  @override
  void dispose() {
    _controller.cancelSetup();
    _password.dispose();
    _confirmation.dispose();
    _typedKey.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_busy && NewPasswordFields.isValid(_password.text, _confirmation.text);

  Future<void> _create() async {
    if (!_canCreate) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = await _controller.prepareVault(_password.text);
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      setState(() {
        _recoveryKeyText = text;
        _step = _Step.showKey;
      });
    } on Exception {
      if (mounted) setState(() => _error = l10n.setupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _typedKey.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _controller.confirmSetup(_typedKey.text);
    } on InvalidRecoveryKeyException {
      if (mounted) {
        setState(() => _error = _mismatchHint(l10n, l10n.recoveryKeyInvalid));
      }
    } on WrongSecretException {
      if (mounted) {
        setState(() => _error = _mismatchHint(l10n, l10n.recoveryKeyWrong));
      }
    } on Exception {
      if (mounted) setState(() => _error = l10n.setupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mismatchHint(AppLocalizations l10n, String fallback) =>
      recoveryKeyMismatchHint(
        l10n,
        shown: _recoveryKeyText,
        typed: _typedKey.text,
        fallback: fallback,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KkScaffold(
      appBar: kkRootAppBar(context, title: l10n.setupTitle),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Adım göstergesi dolarak ilerler (madde 4.7).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: ExcludeSemantics(
                child: KeyedSubtree(
                  key: OnboardingScreen.stepIndicatorKey,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_step.index + 1) / _Step.values.length),
                    duration: KkMotion.of(context, KkMotion.enter),
                    curve: KkMotion.standard,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                // Adımlar arası içerik yana kayar.
                child: AnimatedSwitcher(
                  duration: KkMotion.of(context, KkMotion.enter),
                  switchInCurve: KkMotion.standard,
                  switchOutCurve: KkMotion.standard,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(_step);
                    // Kayıp giden adım (ör. kurtarma anahtarı) yalnızca
                    // çizilir: dokunulmaz, odaklanmaz, ekran okuyucu okumaz.
                    return IgnorePointer(
                      ignoring: !incoming,
                      child: ExcludeFocus(
                        excluding: !incoming,
                        child: ExcludeSemantics(
                          excluding: !incoming,
                          child: FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: Offset(incoming ? 0.25 : -0.25, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _passwordStep(AppLocalizations l10n) {
    return [
      const Center(child: KeyKeyLogo(size: 72)),
      const SizedBox(height: 16),
      Text(l10n.setupIntro),
      const SizedBox(height: 12),
      RecoveryWarningCard(text: l10n.setupPasswordWarning),
      const SizedBox(height: 16),
      GlassSurface(
        padding: const EdgeInsets.all(12),
        child: NewPasswordFields(
          password: _password,
          confirmation: _confirmation,
          enabled: !_busy,
          autofocus: true,
          onSubmitted: _create,
        ),
      ),
      if (_error != null) ...[const SizedBox(height: 12), _ErrorText(_error!)],
      const SizedBox(height: 16),
      ListenableBuilder(
        listenable: Listenable.merge([_password, _confirmation]),
        builder: (context, _) => FilledButton(
          onPressed: _canCreate ? _create : null,
          child: Text(_busy ? l10n.setupCreating : l10n.setupCreate),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : () => pickBackupToRestore(context, ref),
        child: Text(l10n.restoreTitle),
      ),
      TextButton(
        onPressed: _busy ? null : () => context.push(AppRoutes.syncSetup),
        child: Text(l10n.setupFromSync),
      ),
    ];
  }

  List<Widget> _showKeyStep(AppLocalizations l10n) {
    return [
      Text(l10n.recoveryShowIntro),
      const SizedBox(height: 12),
      RecoveryWarningCard(text: l10n.recoveryShowWarning),
      const SizedBox(height: 16),
      RecoveryKeyCard(text: _recoveryKeyText ?? '', gated: false),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () => setState(() {
          _step = _Step.verifyKey;
          _error = null;
        }),
        child: Text(l10n.recoveryShowContinue),
      ),
    ];
  }

  List<Widget> _verifyStep(AppLocalizations l10n) {
    return [
      Text(l10n.recoveryVerifyIntro),
      const SizedBox(height: 16),
      RecoveryKeyEntry(
        controller: _typedKey,
        enabled: !_busy,
        gated: false,
        errorText: _error,
        onChanged: () => setState(() {}),
        onRead: () => setState(() => _error = null),
        onSubmitted: _verify,
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _busy ? null : _verify,
        child: Text(l10n.recoveryVerifyConfirm),
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
}

class _ErrorText extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
