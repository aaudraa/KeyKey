import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_rolling_text.dart';

Widget _host(Widget child, {bool disable = false}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disable),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('KkRollingText', () {
    testWidgets('yalnızca değişen karakter kayar, ötekiler kıpırdamaz', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const KkRollingText(text: '123456')));
      expect(find.text('123456'), findsOneWidget);
      await tester.pumpWidget(_host(const KkRollingText(text: '123457')));
      await tester.pump();
      await tester.pump(KkMotion.base ~/ 2);
      // Kayarken eski ve yeni son rakam birlikte görünür.
      expect(find.text('6'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('7'), matching: find.byType(Opacity)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: find.text('1'), matching: find.byType(Opacity)),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.text('123457'), findsOneWidget);
      expect(find.text('6'), findsNothing);
    });

    testWidgets('kayarken metin tek parça kalır, boyu değişmez', (
      tester,
    ) async {
      const style = TextStyle(fontSize: 24, letterSpacing: 2);
      await tester.pumpWidget(
        _host(const KkRollingText(text: '123 456', style: style)),
      );
      final rest = tester.getSize(find.byType(KkRollingText));
      await tester.pumpWidget(
        _host(const KkRollingText(text: '123 457', style: style)),
      );
      await tester.pump();
      await tester.pump(KkMotion.base ~/ 2);
      // Yeni metin tek parça olarak yerinde; yalnızca değişen rakam kayar.
      expect(find.text('123 457', findRichText: true), findsOneWidget);
      expect(tester.getSize(find.byType(KkRollingText)), rest);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(KkRollingText)), rest);
    });

    testWidgets('kayarken ekran okuyucu yalnızca yeni metni okur', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const KkRollingText(text: '111')));
      await tester.pumpWidget(_host(const KkRollingText(text: '222')));
      await tester.pump();
      expect(find.bySemanticsLabel('222'), findsOneWidget);
      expect(find.bySemanticsLabel('111'), findsNothing);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('animasyonlar kapalıyken anında', (tester) async {
      await tester.pumpWidget(
        _host(const KkRollingText(text: '123456'), disable: true),
      );
      await tester.pumpWidget(
        _host(const KkRollingText(text: '123457'), disable: true),
      );
      await tester.pump();
      expect(find.text('123457'), findsOneWidget);
    });
  });

  group('KkScrambleText', () {
    String shown(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('karisan'))).data!;

    testWidgets('yeni değerde 250 ms karışır, sonra gerçek değer', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const KkScrambleText(text: 'ilk-parola', textKey: Key('karisan')),
        ),
      );
      expect(shown(tester), 'ilk-parola');
      await tester.pumpWidget(
        _host(
          const KkScrambleText(text: 'yeni-parola', textKey: Key('karisan')),
        ),
      );
      await tester.pump();
      await tester.pump(KkScrambleText.duration ~/ 2);
      expect(shown(tester), hasLength('yeni-parola'.length));
      expect(shown(tester), isNot('yeni-parola'));
      // Süs karakterler ekran okuyucuya gitmez.
      final node = tester.getSemantics(find.byType(KkScrambleText));
      expect(node.label, 'yeni-parola');
      await tester.pump(KkScrambleText.duration);
      expect(shown(tester), 'yeni-parola');
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('animasyonlar kapalıyken karışmaz', (tester) async {
      await tester.pumpWidget(
        _host(
          const KkScrambleText(text: 'a', textKey: Key('karisan')),
          disable: true,
        ),
      );
      await tester.pumpWidget(
        _host(
          const KkScrambleText(text: 'b', textKey: Key('karisan')),
          disable: true,
        ),
      );
      await tester.pump();
      expect(shown(tester), 'b');
    });
  });
}
