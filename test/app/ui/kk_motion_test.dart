import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Değerler `resources/docs/tasarim-siyah-beyaz.md`, "Ortak değerler".
void main() {
  test('süreler belgedeki gibi', () {
    expect(KkMotion.fast, const Duration(milliseconds: 150));
    expect(KkMotion.base, const Duration(milliseconds: 250));
    expect(KkMotion.enter, const Duration(milliseconds: 350));
    expect(KkMotion.panelOpen, const Duration(milliseconds: 400));
    expect(KkMotion.panelClose, const Duration(milliseconds: 200));
    expect(KkMotion.emphasis, const Duration(milliseconds: 450));
    expect(KkMotion.stagger, const Duration(milliseconds: 40));
    expect(KkMotion.staggerMax, 8);
    expect(KkMotion.shake, const Duration(milliseconds: 300));
  });

  test('eğriler belgedeki gibi', () {
    expect(KkMotion.spring, const Cubic(0.2, 1.35, 0.4, 1));
    expect(KkMotion.standard, Curves.easeOutCubic);
    expect(KkMotion.exit, Curves.easeInCubic);
  });

  test('tek hareketler 150-450 ms arasında', () {
    for (final d in [
      KkMotion.fast,
      KkMotion.base,
      KkMotion.enter,
      KkMotion.panelOpen,
      KkMotion.panelClose,
      KkMotion.emphasis,
      KkMotion.shake,
    ]) {
      expect(d.inMilliseconds, inInclusiveRange(150, 450));
    }
  });
}
