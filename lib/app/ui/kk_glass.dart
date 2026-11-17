import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_metrics.dart';

/// Cam yüzeylerin ve zeminin renkleri. Değerler
/// `resources/docs/tasarim-siyah-beyaz-plani.md` belgesindeki tabloda.
@immutable
class KkGlass extends ThemeExtension<KkGlass> {
  const new({
    required this.fill,
    required this.fillStrong,
    required this.raised,
    required this.navFill,
    required this.border,
    required this.hairline,
    required this.highlight,
    required this.shadow,
    required this.scrim,
    required this.accent,
    required this.tint,
    required this.brand,
    required this.onBrand,
    required this.brandStroke,
    required this.ground,
    required this.blobs,
    required this.blobAlpha,
  });

  /// Kartların dolu (saydam olmayan) dolgusu: telefon denemesi 4'te buzlu
  /// cam kartların okunurluğu düşürdüğü görüldü.
  final Color fill;

  /// "+" kutusu gibi bulanık yüzeylerin dolgusu.
  final Color fillStrong;

  /// Ekranın üstüne açılan dolu yüzeyler: alttan açılan pencere, ⋮ menüsü,
  /// üst bildirim. Saydam değil; cam yalnızca alt menüde ve "+" kutusunda
  /// (proje sahibi, 2026-11-17). Koyu temada karttan bir ton açık, altındaki
  /// kartlardan ayrılsın.
  final Color raised;

  /// Alt menünün dolgusu: kartlardan saydam, altından kayan içerik bulanık
  /// ve canlı görünsün.
  final Color navFill;

  /// Kartın kenarı.
  final Color border;

  /// Satır arası çizgiler, ayraçlar, çip ve düğme kenarları. Koyu temada
  /// kart kenarından belirgin: kartın üstünde seçilmeli.
  final Color hairline;

  /// Cam yüzeyin üst kenarındaki ince parlak çizgi.
  final Color highlight;
  final Color shadow;

  /// Açılan kutuların arkasındaki karartma.
  final Color scrim;

  /// Simge ve çizimler: siyah-beyaz temada yazı rengiyle aynı.
  final Color accent;

  /// Seçili ya da basılı zemin (seçili sekme, "Üret" düğmesi).
  final Color tint;

  /// Turuncu. Yalnızca "+" düğmesinde ve ekranın ana düğmesinde dolgu
  /// olarak kullanılır.
  final Color brand;

  /// Turuncunun üstündeki yazı ve simge.
  final Color onBrand;

  /// İnce turuncu çizgi (2FA halkası): zeminde 3:1 görünsün diye açık
  /// temada daha koyu.
  final Color brandStroke;

  /// Zeminin düz rengi.
  final Color ground;

  /// Renksiz ışık lekeleri.
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
      raised: c(raised, other.raised),
      navFill: c(navFill, other.navFill),
      border: c(border, other.border),
      hairline: c(hairline, other.hairline),
      highlight: c(highlight, other.highlight),
      shadow: c(shadow, other.shadow),
      scrim: c(scrim, other.scrim),
      accent: c(accent, other.accent),
      tint: c(tint, other.tint),
      brand: c(brand, other.brand),
      onBrand: c(onBrand, other.onBrand),
      brandStroke: c(brandStroke, other.brandStroke),
      ground: c(ground, other.ground),
      blobs: [
        for (var i = 0; i < blobs.length; i++) c(blobs[i], other.blobs[i]),
      ],
      blobAlpha: ui.lerpDouble(blobAlpha, other.blobAlpha, t)!,
    );
  }
}

/// Yarı saydam cam yüzey: dolgu, ince kenar ve yumuşak gölge; [sheen] ile
/// üstten sönen parıltı. Gerçek bulanıklaştırma ([blur]) pahalıdır; yalnızca
/// içeriğin altından kaydığı ya da üstüne açıldığı yüzeylerde kullanılır.
class GlassSurface extends StatelessWidget {
  const new({
    required this.child,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(KkMetrics.cardRadius),
    ),
    this.blur = false,
    this.strong = false,
    this.padding,
    this.fill,
    this.vibrant = false,
    this.sheen = false,
    super.key,
  });

  static const double blurSigma = 20;

  /// Alt menünün buzlu camı: arkadaki şekiller dağılır ama seçilir; yazı
  /// okunmaz.
  static const double navBlurSigma = 10;

  /// Bulanık arkaplanın renk doygunluğu artışı ([vibrant]).
  static const double vibrance = 2.1;

  /// Temadaki dolgu yerine kullanılacak renk (ör. alt menü).
  final Color? fill;

  /// Arkadaki içeriği daha güçlü bulanıklaştırıp renklerini canlandırır
  /// (yalnızca [blur] ile).
  final bool vibrant;

  /// Üstten aşağı sönen beyaz parıltı: buzlu camın ışığı (alt menü).
  ///
  /// Tepede ince parlak şerit yok: kartlarda (telefon denemesi 6) ve alt
  /// menüde iki temada da beyaz çizgi olarak göze batıyordu (telefon
  /// denemesi 17).
  final bool sheen;

  final Widget child;
  final BorderRadius borderRadius;
  final bool blur;

  /// "+" kutusu gibi bulanık yüzeyler için daha dolgun cam.
  final bool strong;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
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
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        glass.highlight.withValues(
                          alpha: glass.highlight.a * 0.4,
                        ),
                        glass.highlight.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
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
                  outer: kkSaturation(vibrance),
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

/// Renk doygunluğunu [amount] katına çıkaran süzgeç (1 değişmez, 0 gri
/// tonlama).
ColorFilter kkSaturation(double amount) {
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
