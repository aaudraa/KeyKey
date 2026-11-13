import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_glass.dart';

/// WCAG bağıl parlaklığı.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG kontrast oranı.
double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Yarı saydam [fg]'nin opak [bg] üstündeki görünen rengi.
Color over(Color bg, Color fg) {
  final a = fg.a;
  double mix(double b, double f) => b * (1 - a) + f * a;
  return Color.from(
    alpha: 1,
    red: mix(bg.r, fg.r),
    green: mix(bg.g, fg.g),
    blue: mix(bg.b, fg.b),
  );
}

void main() {
  group('sabit renkler', () {
    test('açık tema', () {
      final theme = AppTheme.light;
      final glass = theme.extension<KkGlass>()!;
      expect(theme.colorScheme.primary, const Color(0xFF111111));
      expect(theme.colorScheme.onSurface, const Color(0xFF111111));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF525252));
      expect(glass.ground, const Color(0xFFE6E6E8));
      expect(glass.blobs, const [
        Color(0xFFFFFFFF),
        Color(0xFFA9A9AE),
        Color(0xFFFFFFFF),
      ]);
      expect(glass.blobAlpha, 0.45);
      expect(glass.brand, const Color(0xFFF26B1D));
      expect(glass.brandStroke, const Color(0xFFC2470C));
      expect(glass.onBrand, const Color(0xFF1A0D05));
      expect(glass.accent, theme.colorScheme.onSurface);
      // Telefon denemesi 4: kartlar buzlu cam değil, dolu beyaz.
      expect(glass.fill, Colors.white);
    });

    test('koyu tema', () {
      final theme = AppTheme.dark;
      final glass = theme.extension<KkGlass>()!;
      expect(theme.colorScheme.primary, const Color(0xFFF4F4F4));
      expect(theme.colorScheme.onSurface, const Color(0xFFF4F4F4));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFADADAD));
      expect(glass.ground, const Color(0xFF000000));
      expect(glass.blobs, const [
        Color(0xFF5A5A5E),
        Color(0xFF3A3A3E),
        Color(0xFF4A4A4E),
      ]);
      expect(glass.blobAlpha, 0.5);
      expect(glass.brand, const Color(0xFFFF8A4C));
      expect(glass.brandStroke, const Color(0xFFFF8A4C));
      expect(glass.onBrand, const Color(0xFF1A0D05));
      expect(glass.accent, theme.colorScheme.onSurface);
      // Kartlar dolu koyu gri; arkadaki lekeler kartın içinden görünmez.
      expect(glass.fill, const Color(0xFF1C1C1E));
    });

    test('zemin saydam, ekranlar kendi zeminini çizer', () {
      expect(AppTheme.light.scaffoldBackgroundColor.a, 0);
      expect(AppTheme.dark.scaffoldBackgroundColor.a, 0);
    });

    test('simge turuncusu ayrı tutuluyor', () {
      expect(KkColors.brandOrange, const Color(0xFFF26B1D));
    });
  });

  for (final (name, theme) in [
    ('açık', AppTheme.light),
    ('koyu', AppTheme.dark),
  ]) {
    group('$name tema kontrastı', () {
      final scheme = theme.colorScheme;
      final glass = theme.extension<KkGlass>()!;
      final grounds = [
        for (final g in glass.worstGrounds()) ...[g, over(g, glass.fill)],
      ];

      test('en kötü zemin noktası en az dört renk', () {
        expect(glass.worstGrounds(), hasLength(4));
      });

      for (final (role, color) in [
        ('yazı', scheme.onSurface),
        ('ikincil yazı', scheme.onSurfaceVariant),
        ('hata', scheme.error),
      ]) {
        test('$role zeminin ve kartın her yerinde okunur', () {
          for (final bg in grounds) {
            expect(
              contrast(color, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$bg',
            );
          }
        });
      }

      test('alt menü camı kartlardan saydam, simgeleri yine okunur', () {
        // Menü altından kayan içerik bulanık da olsa görünsün.
        expect(glass.navFill.a, lessThan(0.5));
        for (final bg in grounds) {
          final bar = over(bg, glass.navFill);
          expect(
            contrast(scheme.onSurface, bar),
            greaterThanOrEqualTo(4.5),
            reason: '$bg',
          );
          expect(
            contrast(glass.accent, over(bar, glass.tint)),
            greaterThanOrEqualTo(3.0),
            reason: '$bg',
          );
        }
      });

      test('vurgulu simge her yerde görünür', () {
        for (final bg in grounds) {
          expect(
            contrast(glass.accent, bg),
            greaterThanOrEqualTo(3.0),
            reason: '$bg',
          );
        }
      });

      test('düz SnackBar opak ve yazısı okunur', () {
        // showKkSnack kendi camını çizer; doğrudan SnackBar gösteren yerler
        // temaya kalır.
        final snack = theme.snackBarTheme;
        expect(snack.backgroundColor?.a, 1);
        expect(
          contrast(snack.contentTextStyle!.color!, snack.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(snack.actionTextColor!, snack.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('turuncu düğmenin yazısı okunur', () {
        expect(contrast(glass.onBrand, glass.brand), greaterThanOrEqualTo(4.5));
      });

      test('ince turuncu çizgi (2FA halkası) her yerde görünür', () {
        for (final bg in grounds) {
          expect(
            contrast(glass.brandStroke, bg),
            greaterThanOrEqualTo(3.0),
            reason: '$bg',
          );
        }
      });

      test('ana düğme düz turuncu, köşeli ve alçak', () {
        final style = theme.filledButtonTheme.style!;
        expect(style.minimumSize?.resolve({}), const Size(64, 44));
        expect(
          style.shape?.resolve({}),
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        );
        expect(style.foregroundColor?.resolve({}), glass.onBrand);
      });

      test('seçili anahtar siyah-beyaz', () {
        final track = theme.switchTheme.trackColor!.resolve({
          WidgetState.selected,
        });
        expect(track, scheme.onSurface);
      });
    });
  }

  test("Android'de sayfalar tahmini geri hareketiyle kayar", () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
    }
  });

  test('ana etkinlik tahmini geri hareketine açık', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final main = RegExp(r'<activity\s+android:name="\.MainActivity"[^>]*>')
        .firstMatch(manifest)!
        .group(0)!;
    expect(main, contains('android:enableOnBackInvokedCallback="true"'));
  });
}
