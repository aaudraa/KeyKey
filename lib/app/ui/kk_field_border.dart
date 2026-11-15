import 'package:flutter/material.dart';

/// Yazı alanının kenarı: kutunun dört yanını yuvarlak köşeli ince bir
/// çerçeveyle çizer, ama [isOutline] yanlış olduğu için etiket çizginin
/// üstüne değil kutunun içine oturur.
///
/// Alt çizgi yuvarlak köşelerde kıvrılıp incelerek bitiyor, bozuk
/// görünüyordu; dış çizgili stilde de etiket çizgiye oturduğu için kart
/// yarısını kesiyordu (telefon denemeleri 5 ve 6).
class KkFieldBorder extends InputBorder {
  const new({
    super.borderSide = BorderSide.none,
    this.borderRadius = BorderRadius.zero,
  });

  final BorderRadius borderRadius;

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  KkFieldBorder copyWith({BorderSide? borderSide, BorderRadius? radius}) =>
      KkFieldBorder(
        borderSide: borderSide ?? this.borderSide,
        borderRadius: radius ?? borderRadius,
      );

  @override
  KkFieldBorder scale(double t) => KkFieldBorder(
    borderSide: borderSide.scale(t),
    borderRadius: borderRadius * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is KkFieldBorder) {
      return KkFieldBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is KkFieldBorder) {
      return KkFieldBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(
      borderRadius
          .resolve(textDirection)
          .toRRect(rect)
          .deflate(borderSide.width),
    );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.resolve(textDirection).toRRect(rect));

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none || borderSide.width == 0) return;
    // Çizgi kutunun içine çizilir ki kartın kenarına taşmasın.
    final rrect = borderRadius
        .resolve(textDirection)
        .toRRect(rect)
        .deflate(borderSide.width / 2);
    canvas.drawRRect(rrect, borderSide.toPaint());
  }

  @override
  bool operator ==(Object other) =>
      other is KkFieldBorder &&
      other.borderSide == borderSide &&
      other.borderRadius == borderRadius;

  @override
  int get hashCode => Object.hash(borderSide, borderRadius);
}
