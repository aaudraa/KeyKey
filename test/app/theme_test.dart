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
      expect(theme.colorScheme.primary, const Color(0xFF9A3A08));
      expect(theme.extension<KkGlass>()!.ground, const Color(0xFFF3EEF4));
    });

    test('koyu tema', () {
      final theme = AppTheme.dark;
      expect(theme.colorScheme.primary, const Color(0xFFFFA873));
      expect(theme.extension<KkGlass>()!.ground, const Color(0xFF0C0B10));
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
        ('vurgulu yazı', scheme.primary),
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

      test('ana düğmenin yazısı geçişin iki ucunda okunur', () {
        for (final c in glass.ctaGradient.colors) {
          expect(contrast(glass.onCta, c), greaterThanOrEqualTo(4.5));
        }
        expect(glass.ctaGradient.colors, [KkColors.ctaStart, KkColors.ctaEnd]);
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

  test('baş harf kutularında beyaz harf okunur', () {
    expect(KkColors.avatarPalette, hasLength(10));
    for (final c in KkColors.avatarPalette) {
      expect(contrast(Colors.white, c), greaterThanOrEqualTo(4.5));
    }
  });
}
