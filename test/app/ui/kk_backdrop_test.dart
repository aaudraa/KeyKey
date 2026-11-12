import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';

double _luminance(int r, int g, int b) {
  double channel(int v) {
    final c = v / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) * 1.0;
  }

  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
}

double _colorLuminance(Color c) =>
    _luminance((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());

Widget _host(ThemeData theme, Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 800),
        disableAnimations: disableAnimations,
      ),
      child: child,
    ),
  );
}

void main() {
  for (final (name, theme) in [
    ('açık', AppTheme.light),
    ('koyu', AppTheme.dark),
  ]) {
    testWidgets('$name temada lekeler en kötü zemin noktasını aşmaz', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(theme, RepaintBoundary(key: key, child: const KkBackdrop())),
      );

      final glass = theme.extension<KkGlass>()!;
      final lums = glass.worstGrounds().map(_colorLuminance).toList();
      final lo = lums.reduce(math.min) - 0.01;
      final hi = lums.reduce(math.max) + 0.01;

      final bytes = await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data!;
      });
      var tinted = 0;
      for (var i = 0; i < bytes!.lengthInBytes; i += 4) {
        final l = _luminance(
          bytes.getUint8(i),
          bytes.getUint8(i + 1),
          bytes.getUint8(i + 2),
        );
        expect(l, inInclusiveRange(lo, hi), reason: 'piksel ${i ~/ 4}');
        if ((l - lums.first).abs() > 0.02) tinted++;
      }
      // Lekeler gerçekten çizilmiş olmalı.
      expect(tinted, greaterThan(10000));
    });
  }

  testWidgets('kaymayan zemin kare istemez', (tester) async {
    await tester.pumpWidget(_host(AppTheme.light, const KkBackdrop()));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('kayan zemin kare istiyor', (tester) async {
    await tester.pumpWidget(
      _host(AppTheme.light, const KkBackdrop(drifting: true)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('görünmeyen (TickerMode kapalı) kayan zemin durur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AppTheme.light,
        const TickerMode(enabled: false, child: KkBackdrop(drifting: true)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('animasyonlar kapalıyken kayan zemin de durur', (tester) async {
    await tester.pumpWidget(
      _host(
        AppTheme.light,
        const KkBackdrop(drifting: true),
        disableAnimations: true,
      ),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets("KkScaffold zemini çizer ve kendi Scaffold'u saydam", (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(AppTheme.light, const KkScaffold(body: Text('içerik'))),
    );
    expect(find.byType(KkBackdrop), findsOneWidget);
    expect(find.text('içerik'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor?.a ?? 0, 0);
  });

  group('GlassSurface', () {
    testWidgets('bulanıklık istenmezse BackdropFilter yok', (tester) async {
      await tester.pumpWidget(
        _host(AppTheme.light, const GlassSurface(child: Text('kart'))),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('kart'), findsOneWidget);
    });

    testWidgets('bulanıklık istenirse BackdropFilter var', (tester) async {
      await tester.pumpWidget(
        _host(
          AppTheme.light,
          const GlassSurface(blur: true, strong: true, child: Text('menü')),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('KkMotion', () {
    testWidgets('animasyonlar kapalıyken süre sıfır', (tester) async {
      late Duration on;
      late Duration off;
      await tester.pumpWidget(
        _host(
          AppTheme.light,
          Builder(
            builder: (context) {
              on = KkMotion.of(context, KkMotion.base);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          AppTheme.light,
          Builder(
            builder: (context) {
              off = KkMotion.of(context, KkMotion.base);
              return const SizedBox();
            },
          ),
          disableAnimations: true,
        ),
      );
      expect(on, const Duration(milliseconds: 250));
      expect(off, Duration.zero);
    });
  });
}
