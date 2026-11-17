import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_glass.dart';

Widget _host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

Finder _strip(KkGlass glass) => find.byWidgetPredicate(
  (w) => w is ColoredBox && w.color == glass.highlight,
);

void main() {
  for (final (name, theme) in [
    ('açık', AppTheme.light),
    ('koyu', AppTheme.dark),
  ]) {
    final glass = theme.extension<KkGlass>()!;

    // Telefon denemesi 6: kartın tepesindeki ince beyaz şerit koyu temada
    // siyahın, açık temada kremin üstünde göze batıyordu.
    testWidgets('$name: kartın tepesinde parlak şerit yok', (tester) async {
      await tester.pumpWidget(
        _host(
          theme,
          const GlassSurface(child: SizedBox(width: 200, height: 80)),
        ),
      );
      expect(_strip(glass), findsNothing);
    });

    // Telefon denemesi 17: koyu temada alt menünün tepesindeki ince beyaz
    // çizgi de istenmedi. Açık temada kremin üstünde belli belirsiz kalır.
    testWidgets(
      name == 'açık'
          ? '$name: alt menünün camında parlak şerit kalır'
          : '$name: alt menünün camında da parlak şerit yok',
      (tester) async {
        await tester.pumpWidget(
          _host(
            theme,
            const GlassSurface(
              sheen: true,
              child: SizedBox(width: 200, height: 80),
            ),
          ),
        );
        expect(_strip(glass), name == 'açık' ? findsOneWidget : findsNothing);
      },
    );
  }
}
