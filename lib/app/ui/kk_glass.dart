import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:keykey/app/theme.dart';

/// Cam yüzeylerin ve renkli zeminin renkleri. Değerler
/// `resources/docs/tasarim-cam-plani.md` belgesindeki tabloda.
@immutable
class KkGlass extends ThemeExtension<KkGlass> {
  const new({
    required this.fill,
    required this.fillStrong,
    required this.navFill,
    required this.capsule,
    required this.border,
    required this.highlight,
    required this.shadow,
    required this.scrim,
    required this.accent,
    required this.accentContainer,
    required this.onCta,
    required this.ctaGradient,
    required this.ground,
    required this.blobs,
    required this.blobAlpha,
  });

  /// Kartların yarı saydam dolgusu.
  final Color fill;

  /// Menü, kutu ve pencere gibi bulanık yüzeylerin dolgusu.
  final Color fillStrong;

  /// Alt menünün dolgusu: kartlardan saydam, altından kayan içerik bulanık
  /// ve canlı görünsün.
  final Color navFill;

  /// Alt menüde seçili sekmenin kapsülü.
  final Color capsule;
  final Color border;

  /// Cam yüzeyin üst kenarındaki ince parlak çizgi.
  final Color highlight;
  final Color shadow;

  /// Açılan kutuların arkasındaki karartma.
  final Color scrim;

  /// Vurgulu simge ve çizimler. Yazı için `colorScheme.primary` kullanılır.
  final Color accent;

  /// Simge kutularının ve "Üret" gibi düğmelerin zemini.
  final Color accentContainer;

  /// Ana düğmenin üstündeki yazı ve simge.
  final Color onCta;
  final LinearGradient ctaGradient;

  /// Zeminin düz rengi.
  final Color ground;

  /// Şeftali, lila ve pembe lekeler.
  final List<Color> blobs;

  /// Lekenin merkezindeki görünürlük.
  final double blobAlpha;

  /// Temada yoksa (ör. temasız test uygulaması) parlaklığa uyan KeyKey
  /// değerleri.
  static KkGlass of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<KkGlass>() ??
        (theme.brightness == Brightness.dark ? AppTheme.dark : AppTheme.light)
            .extension<KkGlass>()!;
  }

  /// Zemin ve her lekenin en koyu (koyu temada en açık) noktası. Kontrast bu
  /// renklere göre ölçülür.
  List<Color> worstGrounds() => [
    ground,
    for (final blob in blobs)
      Color.alphaBlend(blob.withValues(alpha: blobAlpha), ground),
  ];

  @override
  KkGlass copyWith() => this;

  @override
  KkGlass lerp(KkGlass? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return KkGlass(
      fill: c(fill, other.fill),
      fillStrong: c(fillStrong, other.fillStrong),
      navFill: c(navFill, other.navFill),
      capsule: c(capsule, other.capsule),
      border: c(border, other.border),
      highlight: c(highlight, other.highlight),
      shadow: c(shadow, other.shadow),
      scrim: c(scrim, other.scrim),
      accent: c(accent, other.accent),
      accentContainer: c(accentContainer, other.accentContainer),
      onCta: c(onCta, other.onCta),
      ctaGradient: LinearGradient.lerp(ctaGradient, other.ctaGradient, t)!,
      ground: c(ground, other.ground),
      blobs: [
        for (var i = 0; i < blobs.length; i++) c(blobs[i], other.blobs[i]),
      ],
      blobAlpha: ui.lerpDouble(blobAlpha, other.blobAlpha, t)!,
    );
  }
}

/// Yarı saydam cam yüzey: dolgu, ince kenar, üstte parlak çizgi ve yumuşak
/// gölge. Gerçek bulanıklaştırma ([blur]) pahalıdır; yalnızca içeriğin
/// altından kaydığı ya da üstüne açıldığı yüzeylerde kullanılır.
class GlassSurface extends StatelessWidget {
  const new({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.blur = false,
    this.strong = false,
    this.padding,
    this.fill,
    this.vibrant = false,
    super.key,
  });

  static const double blurSigma = 20;

  /// Alt menünün bulanıklığı: içerik daha çok dağılır, yazı seçilmez.
  static const double navBlurSigma = 36;

  /// Bulanık arkaplanın renk doygunluğu artışı ([vibrant]).
  static const double vibrance = 2.1;

  /// Temadaki dolgu yerine kullanılacak renk (ör. alt menü).
  final Color? fill;

  /// Arkadaki içeriği daha güçlü bulanıklaştırıp renklerini canlandırır
  /// (yalnızca [blur] ile).
  final bool vibrant;

  final Widget child;
  final BorderRadius borderRadius;
  final bool blur;

  /// Menü, kutu ve pencere için daha dolgun cam.
  final bool strong;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    final inset = borderRadius.topLeft.x.clamp(0.0, 40.0);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? (strong ? glass.fillStrong : glass.fill),
        borderRadius: borderRadius,
        border: Border.all(color: glass.border),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // İçteki ListTile ve InkWell'in dalgası cam dolgunun üstünde
          // görünsün; dalga köşelerden taşmasın.
          Material(
            type: MaterialType.transparency,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: padding == null
                ? child
                : Padding(padding: padding!, child: child),
          ),
          Positioned(
            top: 0,
            left: inset,
            right: inset,
            height: 1,
            child: IgnorePointer(child: ColoredBox(color: glass.highlight)),
          ),
        ],
      ),
    );
    if (blur) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: vibrant
              ? ui.ImageFilter.compose(
                  outer: _saturation(vibrance),
                  inner: ui.ImageFilter.blur(
                    sigmaX: navBlurSigma,
                    sigmaY: navBlurSigma,
                  ),
                )
              : ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: surface,
        ),
      );
    }
    return CustomPaint(
      painter: _OuterShadowPainter(glass.shadow, borderRadius),
      child: surface,
    );
  }
}

/// Renk doygunluğunu [amount] katına çıkaran süzgeç (1 değişmez).
ColorFilter _saturation(double amount) {
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  final s = amount;
  return ColorFilter.matrix([
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0, //
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// Gölgeyi yalnızca yüzeyin dışına çizer. `BoxShadow` yarı saydam kartın
/// altını da karartır ve yazının kontrastını düşürürdü.
class _OuterShadowPainter extends CustomPainter {
  new(this.color, this.radius);

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final rrect = radius.toRRect(Offset.zero & size);
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect((Offset.zero & size).inflate(60)),
          Path()..addRRect(rrect),
        ),
      )
      ..drawRRect(
        rrect.shift(const Offset(0, 8)),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.color != color || old.radius != radius;
}
