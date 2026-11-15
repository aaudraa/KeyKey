import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Tanıtım sayfasının hareketli çizimi. Sayfa görünür ([active]) olunca
/// giriş hareketi baştan oynar; ardından "Nerede ne var" sayfasında menünün
/// simgeleri iki tur sırayla vurgulanır, "Yedeğin sende" sayfasında simge
/// üç kez nefes alır, sonra durur. Animasyonlar kapalıysa çizim hemen son
/// halindedir ve hiç kare istemez.
class IntroArt extends StatefulWidget {
  const new({required this.page, required this.active, super.key});

  final int page;
  final bool active;

  /// Tanıtımda gerçek logosu gösterilen tek uygulama: KeePassXC'nin logosu
  /// özgür lisanslı (ayrıntı `resources/docs/tanitim.md`).
  static const keepassxcAsset = 'resources/assets/logos/keepassxc.png';

  /// İçe aktarılabilen uygulamalar; logosu olmayanlar yalnızca adıyla.
  static const importApps = [
    'Bitwarden',
    'Chrome',
    'Firefox',
    'KeePassXC',
    'Google Authenticator',
    'Aegis',
    '2FAS',
  ];

  /// Menü iki tur döner ([KkMotion.introTourStep]).
  static const _tourRounds = 2;

  /// Yedek simgesinin nefes sayısı.
  static const _breaths = 3;

  @override
  State<IntroArt> createState() => _IntroArtState();
}

class _IntroArtState extends State<IntroArt> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: KkMotion.introEnter,
  );

  /// Girişten sonraki hareket: menüde sıradaki simge, yedekte nefes.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: widget.page == 2
        ? KkMotion.introTourStep * (4 * IntroArt._tourRounds)
        : KkMotion.breath * IntroArt._breaths,
  );

  bool _reduced = false;

  bool get _loops => widget.page == 2 || widget.page == 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync(restart: false);
  }

  @override
  void didUpdateWidget(IntroArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync(restart: widget.active);
  }

  void _sync({required bool restart}) {
    if (_reduced) {
      _enter.value = 1;
      _loop
        ..stop()
        ..value = 0;
      return;
    }
    if (!widget.active) {
      // Görünmeyen sayfa pil harcamasın.
      _loop.stop();
      return;
    }
    if (restart || _enter.value == 0) {
      _enter.forward(from: 0);
      if (_loops) _loop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.page) {
      0 => _Welcome(enter: _enter),
      1 => _Offline(enter: _enter),
      2 => _Tour(enter: _enter, loop: _loop, reduced: _reduced),
      3 => _Autofill(enter: _enter),
      4 => _Import(enter: _enter),
      _ => _Backup(enter: _enter, loop: _loop),
    };
  }
}

/// [t]'nin [begin]–[end] aralığındaki ilerlemesi, eğriyle.
double _span(
  double t,
  double begin,
  double end, [
  Curve curve = KkMotion.standard,
]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

/// Yukarıdan ya da aşağıdan süzülerek beliren parça.
class _Rise extends StatelessWidget {
  const new({required this.progress, required this.child, this.dy = 12});

  final double progress;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: progress,
    child: Transform.translate(
      offset: Offset(0, (1 - progress) * dy),
      child: child,
    ),
  );
}

/// Sabit yükseklikte, ortalanmış çizim alanı.
class _Canvas extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: KkMetrics.introArtHeight,
    child: Center(child: child),
  );
}

// 1. Hoş geldin: K çizgiyle çizilir, sonra dolar.

class _Welcome extends AnimatedWidget {
  const new({required Animation<double> enter}) : super(listenable: enter);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final settle = _span(t, 0.5, 1, KkMotion.spring);
    return _Canvas(
      child: Semantics(
        label: 'KeyKey',
        image: true,
        child: Transform.scale(
          scale: lerpDouble(0.9, 1, settle),
          child: SizedBox.square(
            dimension: 160,
            child: CustomPaint(painter: _DrawnLogoPainter(t)),
          ),
        ),
      ),
    );
  }
}

class _DrawnLogoPainter extends CustomPainter {
  const new(this.t);

  static final Path _path = KeyKeyLogo.logoPath();

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas
      ..save()
      ..scale(scale);
    final draw = _span(t, 0, 0.65, Curves.easeInOutCubic);
    final fill = _span(t, 0.5, 1);
    if (fill > 0) {
      canvas.drawPath(
        _path,
        Paint()..color = KeyKeyLogo.color.withValues(alpha: fill),
      );
    }
    if (draw > 0 && fill < 1) {
      final stroke = Paint()
        ..color = KeyKeyLogo.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round;
      for (final metric in _path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * draw), stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DrawnLogoPainter old) => old.t != t;
}

// 2. Verilerin sende: telefonda kilit, bulut uzaklaşıp üstü çizilir.

class _Offline extends AnimatedWidget {
  const new({required Animation<double> enter}) : super(listenable: enter);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final ink = Theme.of(context).colorScheme.onSurface;
    final away = _span(t, 0, 0.6);
    final strike = _span(t, 0.4, 0.75);
    final lock = _span(t, 0.55, 0.9, KkMotion.spring);
    return _Canvas(
      child: ExcludeSemantics(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.smartphone_rounded, size: 150, color: ink),
              Transform.scale(
                scale: lock,
                child: Icon(Icons.lock_rounded, size: 40, color: ink),
              ),
              Positioned(
                right: 8,
                top: 30 - 30 * away,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    foregroundPainter: _StrikePainter(strike, ink),
                    child: Icon(
                      Icons.cloud_outlined,
                      size: 64,
                      color: ink.withValues(alpha: lerpDouble(1, 0.4, away)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrikePainter extends CustomPainter {
  const new(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final from = Offset(size.width * 0.1, size.height * 0.15);
    final to = Offset(size.width * 0.9, size.height * 0.85);
    canvas.drawLine(
      from,
      Offset.lerp(from, to, progress)!,
      Paint()
        ..color = color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.progress != progress || old.color != color;
}

// 3. Nerede ne var: menünün kopyası, simgeler sırayla vurgulanır.

class _Tour extends StatelessWidget {
  const new({required this.enter, required this.loop, required this.reduced});

  final Animation<double> enter;
  final Animation<double> loop;
  final bool reduced;

  static const List<IconData> _icons = [
    Icons.lock_outline,
    Icons.shield_outlined,
    Icons.settings_outlined,
    Icons.add_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = [
      (l10n.navVault, l10n.introTourVault),
      (l10n.navAuthenticator, l10n.introTourOtp),
      (l10n.navSettings, l10n.introTourSettings),
      (l10n.vaultAdd, l10n.introTourAdd),
    ];
    return AnimatedBuilder(
      animation: Listenable.merge([enter, loop]),
      builder: (context, _) {
        final t = enter.value;
        // Animasyonlar kapalıyken hiçbir simge vurgulanmaz, hepsi okunur.
        final step = (loop.value * 4 * IntroArt._tourRounds).floor();
        final current = reduced || t < 1 || loop.value >= 1 ? -1 : step % 4;
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KkMetrics.introArtHeight,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Rise(
                progress: _span(t, 0, 0.3),
                child: ExcludeSemantics(child: _TourPill(current: current)),
              ),
              const SizedBox(height: 20),
              for (final (i, (name, caption)) in rows.indexed)
                _Rise(
                  progress: _span(t, 0.25 + 0.12 * i, 0.55 + 0.12 * i),
                  dy: 0,
                  child: _TourRow(
                    icon: _icons[i],
                    name: name,
                    caption: caption,
                    highlighted: i == current,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TourPill extends StatelessWidget {
  const new({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    final ink = Theme.of(context).colorScheme.onSurface;
    Widget tab(int i) => AnimatedScale(
      scale: i == current ? 1.18 : 1,
      duration: KkMotion.of(context, KkMotion.base),
      curve: KkMotion.spring,
      child: AnimatedContainer(
        duration: KkMotion.of(context, KkMotion.base),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i == current ? glass.tint : Colors.transparent,
        ),
        child: Icon(_Tour._icons[i], color: ink, size: 24),
      ),
    );
    return GlassSurface(
      fill: glass.fillStrong,
      borderRadius: const BorderRadius.all(Radius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) tab(i),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 1,
                height: 28,
                child: ColoredBox(color: glass.hairline),
              ),
            ),
            AnimatedScale(
              scale: current == 3 ? 1.18 : 1,
              duration: KkMotion.of(context, KkMotion.base),
              curve: KkMotion.spring,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glass.brand,
                ),
                child: Icon(Icons.add_rounded, color: glass.onBrand),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.name,
    required this.caption,
    required this.highlighted,
  });

  final IconData icon;
  final String name;
  final String caption;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    return AnimatedContainer(
      duration: KkMotion.of(context, KkMotion.base),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? glass.tint : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 22, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(width: 14),
          Text(
            name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              caption,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 4. Otomatik doldurma: öneri belirir, kutular dolar.

class _Autofill extends AnimatedWidget {
  const new({required Animation<double> enter}) : super(listenable: enter);

  static const _user = 'ayse.yilmaz';
  static const _passwordLength = 10;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    final typed = (_user.length * _span(t, 0.5, 0.75)).round();
    final dots = (_passwordLength * _span(t, 0.75, 1)).round();
    final pressed = _span(t, 0.38, 0.46) - _span(t, 0.46, 0.56);

    Widget field(IconData icon, String text) => Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: glass.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KkMetrics.introArtHeight),
      child: Center(
        child: ExcludeSemantics(
          child: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassSurface(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Column(
                    children: [
                      field(
                        Icons.person_outline_rounded,
                        _user.substring(0, typed),
                      ),
                      field(Icons.key_outlined, '•' * dots),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _Rise(
                  progress: _span(t, 0.1, 0.35),
                  child: Transform.scale(
                    scale: 1 - 0.06 * pressed,
                    child: GlassSurface(
                      fill: Color.alphaBlend(
                        glass.tint.withValues(alpha: glass.tint.a * pressed),
                        glass.fillStrong,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const KeyKeyLogo(size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l10n.introAutofillSuggestion,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 5. Geçiş: uygulama rozetleri süzülüp K'ye akar.

class _Import extends AnimatedWidget {
  const new({required Animation<double> enter}) : super(listenable: enter);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    const apps = IntroArt.importApps;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KkMetrics.introArtHeight),
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, name) in apps.indexed)
                  _Rise(
                    progress: _span(t, 0.06 * i, 0.06 * i + 0.35),
                    dy: -16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: glass.fill,
                        border: Border.all(color: glass.hairline),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (name == 'KeePassXC') ...[
                            Image.asset(
                              IntroArt.keepassxcAsset,
                              width: 22,
                              height: 22,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            name,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _Rise(
              progress: _span(t, 0.5, 0.7),
              dy: -8,
              child: Icon(
                Icons.keyboard_double_arrow_down_rounded,
                size: 32,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Transform.scale(
              scale: lerpDouble(0.6, 1, _span(t, 0.62, 1, KkMotion.spring)),
              child: Opacity(
                opacity: _span(t, 0.62, 0.8),
                child: const KeyKeyLogo(size: 72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 6. Yedeğin sende: yedek simgesi belirir, sonra nefes alır.

class _Backup extends StatelessWidget {
  const new({required this.enter, required this.loop});

  final Animation<double> enter;
  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final glass = KkGlass.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([enter, loop]),
      builder: (context, _) {
        final appear = _span(enter.value, 0, 0.6, KkMotion.spring);
        final breath =
            1 + 0.05 * math.sin(loop.value * IntroArt._breaths * 2 * math.pi);
        return _Canvas(
          child: ExcludeSemantics(
            child: Transform.scale(
              scale: lerpDouble(0.6, 1, appear)! * breath,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glass.tint,
                ),
                child: Icon(Icons.backup_outlined, size: 92, color: ink),
              ),
            ),
          ),
        );
      },
    );
  }
}
