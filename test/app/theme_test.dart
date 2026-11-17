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
    // Telefon denemesi 6: açık tema beyaz-gri yerine krem (Claude
    // uygulamasındaki gibi); yazılar da sıcak tonlu.
    test('açık tema', () {
      final theme = AppTheme.light;
      final glass = theme.extension<KkGlass>()!;
      expect(theme.colorScheme.primary, const Color(0xFF141413));
      expect(theme.colorScheme.onSurface, const Color(0xFF141413));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF57564F));
      expect(glass.ground, const Color(0xFFECE9DF));
      expect(glass.blobs, const [
        Color(0xFFFAF9F5),
        Color(0xFFC9C3B1),
        Color(0xFFFAF9F5),
      ]);
      expect(glass.blobAlpha, 0.45);
      expect(glass.brand, const Color(0xFFF26B1D));
      expect(glass.brandStroke, const Color(0xFFC2470C));
      expect(glass.onBrand, const Color(0xFF1A0D05));
      expect(glass.accent, theme.colorScheme.onSurface);
      // Kartlar dolu, saf beyaz değil açık krem.
      expect(glass.fill, const Color(0xFFFAF9F5));
      expect(theme.colorScheme.surface, const Color(0xFFFAF9F5));
    });

    test('açık temada kartın çerçevesi beyaz değil', () {
      // Krem kartın çevresinde beyaz çerçeve görünürdü.
      final glass = AppTheme.light.extension<KkGlass>()!;
      expect(glass.border.r, lessThan(0.5));
    });

    // Telefon denemesi 6: tam siyah zemin, parlak beyaz yazı ve zeminden
    // zor ayrılan kartlar "karışık" görünüyordu; gözü yoruyordu.
    test('koyu tema', () {
      final theme = AppTheme.dark;
      final glass = theme.extension<KkGlass>()!;
      expect(theme.colorScheme.primary, const Color(0xFFE6E6E8));
      expect(theme.colorScheme.onSurface, const Color(0xFFE6E6E8));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFA2A2A8));
      expect(glass.ground, const Color(0xFF121214));
      expect(glass.blobs, const [
        Color(0xFF5A5A5E),
        Color(0xFF3A3A3E),
        Color(0xFF4A4A4E),
      ]);
      expect(glass.blobAlpha, 0.12);
      expect(glass.brand, const Color(0xFFFF8A4C));
      expect(glass.brandStroke, const Color(0xFFFF8A4C));
      expect(glass.onBrand, const Color(0xFF1A0D05));
      expect(glass.accent, theme.colorScheme.onSurface);
      // Kartlar dolu gri; arkadaki lekeler kartın içinden görünmez.
      expect(glass.fill, const Color(0xFF2E2E32));
    });

    test('koyu temada kart zeminin her yerinden belirgin ayrışır', () {
      final glass = AppTheme.dark.extension<KkGlass>()!;
      for (final g in glass.worstGrounds()) {
        expect(
          contrast(glass.fill, g),
          greaterThanOrEqualTo(1.25),
          reason: '$g',
        );
      }
    });

    // Kart kenarı soluk, ama satır arası çizgiler ve düğme kenarları
    // kartın üstünde seçilmeli (inceleme, 2026-11-16).
    test('koyu temada satır çizgisi kartta görünür', () {
      final theme = AppTheme.dark;
      final glass = theme.extension<KkGlass>()!;
      final line = theme.dividerTheme.color!;
      expect(line, glass.hairline);
      expect(theme.colorScheme.outlineVariant, glass.hairline);
      expect(
        contrast(over(glass.fill, line), glass.fill),
        greaterThanOrEqualTo(1.45),
      );
    });

    test('koyu temada kartın çerçevesi neredeyse görünmez', () {
      final glass = AppTheme.dark.extension<KkGlass>()!;
      expect(glass.border.a, lessThanOrEqualTo(0.05));
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
        // Açılan pencere, menü ve bildirim.
        glass.raised,
      ];

      test('açılan yüzeyler dolu, cam yalnızca alt menüde', () {
        expect(glass.raised.a, 1.0);
        if (theme.brightness == Brightness.dark) {
          // Koyu temada kartların üstünde açılan yüzey ayrı seçilsin.
          expect(glass.raised, isNot(glass.fill));
        }
      });

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
