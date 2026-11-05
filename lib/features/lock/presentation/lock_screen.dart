import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kasa kilitliyken açılan ekran.
class LockScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _password = TextEditingController();
  Timer? _waitTimer;
  Duration _wait = Duration.zero;
  bool _busy = false;
  bool _biometricReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWait());
    unawaited(_loadBiometric());
  }

  /// Parmak izi açıksa pencereyi bir kez kendiliğinden gösterir.
  Future<void> _loadBiometric() async {
    final ready = await ref
        .read(vaultControllerProvider.notifier)
        .isBiometricUsable();
    if (!mounted || !ready) return;
    setState(() => _biometricReady = true);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      await _unlockWithBiometric();
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    final BiometricOutcome<void> outcome;
    try {
      outcome = await ref
          .read(vaultControllerProvider.notifier)
          .unlockWithBiometric(
            BiometricTexts(
              title: l10n.biometricUnlockTitle,
              negativeButton: l10n.biometricUseMasterPassword,
            ),
          );
    } on Exception {
      if (mounted) setState(() => _error = l10n.biometricFailed);
      return;
    }
    if (!mounted) return;
    switch (outcome) {
      case BiometricSuccess() || BiometricCancelled():
        break;
      case BiometricLockedOut():
        setState(() => _error = l10n.biometricLockedOut);
      case BiometricInvalidated():
        setState(() {
          _biometricReady = false;
          _error = l10n.biometricInvalidated;
        });
      case BiometricFailed():
        setState(() => _error = l10n.biometricFailed);
    }
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadWait() async {
    final wait = await ref
        .read(vaultControllerProvider.notifier)
        .remainingWait();
    if (mounted) _startWait(wait);
  }

  void _startWait(Duration wait) {
    _waitTimer?.cancel();
    setState(() => _wait = wait);
    if (wait <= Duration.zero) return;
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = _wait - const Duration(seconds: 1);
      setState(() => _wait = left.isNegative ? Duration.zero : left);
      if (_wait == Duration.zero) timer.cancel();
    });
  }

  bool get _canSubmit => !_busy && _wait == Duration.zero;

  Future<void> _submit() async {
    if (!_canSubmit || _password.text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final attempt = await ref
          .read(vaultControllerProvider.notifier)
          .unlockWithPassword(_password.text);
      if (!mounted) return;
      switch (attempt) {
        case PasswordAccepted() || PasswordInterrupted():
          _password.clear();
        case PasswordRejected(:final wait):
          _password.clear();
          setState(() => _error = l10n.lockWrongPassword);
          _startWait(wait);
        case PasswordMustWait(:final wait):
          _startWait(wait);
      }
    } on Exception {
      if (mounted) setState(() => _error = l10n.lockFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _formatWait(Duration wait) {
    final minutes = wait.inMinutes;
    final seconds = wait.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  l10n.lockTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                SecretField(
                  controller: _password,
                  label: l10n.lockPasswordLabel,
                  autofocus: true,
                  enabled: !_busy,
                  errorText: _error,
                  onSubmitted: (_) => _submit(),
                ),
                if (_wait > Duration.zero) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.lockWait(_formatWait(_wait)),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(_busy ? l10n.lockOpening : l10n.lockOpen),
                ),
                if (_biometricReady) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _unlockWithBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l10n.lockUseBiometric),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.push(AppRoutes.recovery),
                  child: Text(l10n.lockForgot),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
