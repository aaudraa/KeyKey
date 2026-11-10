import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';

/// WCAG bağıl parlaklığından kontrast oranı.
double contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('renkler', () {
    test('açık tema krem zemin ve koyu turuncu vurgu', () {
      final theme = AppTheme.light;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF6F1E7));
      expect(theme.colorScheme.primary, const Color(0xFFB4470F));
      expect(theme.colorScheme.onPrimary, const Color(0xFFFFFFFF));
    });

    test('koyu tema sıcak koyu zemin ve açık turuncu vurgu', () {
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1C1A17));
      expect(theme.colorScheme.primary, const Color(0xFFFF8A4C));
      expect(theme.colorScheme.onPrimary, const Color(0xFF1C1A17));
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
      final background = theme.scaffoldBackgroundColor;

      test('yazı zeminde ve kartta okunur', () {
        expect(
          contrast(scheme.onSurface, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('ikincil yazı zeminde, kartta ve kutuda okunur', () {
        for (final bg in [
          background,
          scheme.surface,
          scheme.surfaceContainerHighest,
        ]) {
          expect(
            contrast(scheme.onSurfaceVariant, bg),
            greaterThanOrEqualTo(4.5),
          );
        }
      });

      test('vurgu zeminde, vurgu üstündeki yazı vurguda okunur', () {
        expect(contrast(scheme.primary, background), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }
}
