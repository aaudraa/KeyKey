import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_shake.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kasa kilitliyken açılan ekran.
class LockScreen extends ConsumerStatefulWidget {
  const new({
    this.allowRecovery = true,
    this.subtitle,
    this.compact = false,
    super.key,
  });

  /// `false` ise "Parolamı unuttum" gösterilmez. Doldurma ekranında
  /// kurtarma yapılmaz, kullanıcı ana uygulamaya yönlendirilir.
  final bool allowRecovery;

  /// `true` ise ekran değil, doldurmanın yarım penceresine giren içerik
  /// çizilir: küçük logo, kendi sayfası yok.
  final bool compact;

  /// Başlığın altında gösterilen açıklama, örneğin neyin doldurulacağı.
  final String? subtitle;

  /// Nefes alan parmak izi simgesi (testler için).
  static const Key breathKey = ValueKey('kk-lock-breath');

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _password = TextEditingController();

  /// Yanlış parolada kutunun yana titremesi.
  final _shake = KkShakeController();
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
    _shake.dispose();
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
          _shake.shake();
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
    final ambient =
        !widget.compact &&
        ref.watch(ambientMotionProvider) &&
        !MediaQuery.disableAnimationsOf(context);
    final logo = KeyKeyLogo(size: widget.compact ? 56 : 88);
    final field = KkShake(
      controller: _shake,
      child: GlassSurface(
        padding: const EdgeInsets.all(4),
        child: SecretField(
          controller: _password,
          label: l10n.lockPasswordLabel,
          autofocus: true,
          enabled: !_busy,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _LogoIntro(child: ambient ? _FloatingLogo(child: logo) : logo),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.lockTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(widget.subtitle!, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        field,
        if (_wait > Duration.zero) ...[
          const SizedBox(height: 12),
          Text(l10n.lockWait(_formatWait(_wait)), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_busy ? l10n.lockOpening : l10n.lockOpen),
        ),
        if (_biometricReady) ...[
          const SizedBox(height: 16),
          Center(
            child: _Breathing(
              enabled: ambient,
              child: KkCircleButton(
                icon: Icons.fingerprint_rounded,
                tooltip: l10n.lockUseBiometric,
                size: 56,
                onPressed: _busy ? null : _unlockWithBiometric,
              ),
            ),
          ),
        ],
        if (widget.allowRecovery) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => context.push(AppRoutes.recovery),
            child: Text(l10n.lockForgot),
          ),
        ],
      ],
    );
    if (widget.compact) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: content,
      );
    }
    return KkScaffold(
      livelyBackdrop: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Logonun yavaşça yukarı aşağı süzülmesi (3 saniyede bir tur, 4 dp).
class _FloatingLogo extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo>
    with SingleTickerProviderStateMixin {
  late final _float = AnimationController(vsync: this, duration: KkMotion.float)
    ..repeat();

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _float,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, math.sin(_float.value * 2 * math.pi) * 2),
      child: child,
    ),
    child: widget.child,
  );
}

/// Açılışta K logosu %80 ölçekten ve solarak belirir (madde 4.1).
class _LogoIntro extends StatefulWidget {
  const new({required this.child});

  static const double startScale = 0.8;

  final Widget child;

  @override
  State<_LogoIntro> createState() => _LogoIntroState();
}

class _LogoIntroState extends State<_LogoIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: KkMotion.enter,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, child) {
      final t = KkMotion.standard.transform(_motion.value);
      return Opacity(
        opacity: t,
        child: Transform.scale(
          scale: _LogoIntro.startScale + (1 - _LogoIntro.startScale) * t,
          child: child,
        ),
      );
    },
    child: widget.child,
  );
}

/// Parmak izi simgesinin yavaş nefesi (madde 4.2): ölçek 1 ↔ 1,06,
/// [KkMotion.breath]'te bir tur. Süren hareket kapalıyken çocuğu olduğu
/// gibi çizer.
class _Breathing extends StatefulWidget {
  const new({required this.enabled, required this.child});

  static const double depth = 0.06;

  final bool enabled;
  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: KkMotion.breath,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _motion.repeat();
  }

  @override
  void didUpdateWidget(_Breathing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!widget.enabled) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return KeyedSubtree(
      key: LockScreen.breathKey,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) => Transform.scale(
          scale:
              1 +
              _Breathing.depth *
                  (0.5 - 0.5 * math.cos(_motion.value * 2 * math.pi)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
