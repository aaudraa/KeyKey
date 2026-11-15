import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_secret_text.dart';

Widget _host(String text, {required bool revealed, bool disable = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: Scaffold(
          body: KkSecretText(text: text, revealed: revealed),
        ),
      ),
    );

String _shown(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(KkSecretText),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  testWidgets('gizliyken uzunluğu belli etmeyen sabit noktalar', (
    tester,
  ) async {
    await tester.pumpWidget(_host('kisa', revealed: false));
    expect(_shown(tester), '•' * KkSecretText.concealedLength);
    await tester.pumpWidget(_host('çok-uzun-bir-parola', revealed: false));
    expect(_shown(tester), '•' * KkSecretText.concealedLength);
  });

  testWidgets('açılınca karakterler soldan sağa sırayla döner', (tester) async {
    await tester.pumpWidget(_host('abcdefgh', revealed: false));
    await tester.pumpWidget(_host('abcdefgh', revealed: true));
    await tester.pump();
    await tester.pump(KkSecretText.perChar * 3);
    expect(_shown(tester), 'abc•••••');
    await tester.pumpAndSettle();
    expect(_shown(tester), 'abcdefgh');
  });

  testWidgets('gizlerken tersine, sonunda sabit noktalar', (tester) async {
    await tester.pumpWidget(_host('abcdefgh', revealed: true));
    await tester.pumpWidget(_host('abcdefgh', revealed: false));
    await tester.pump();
    await tester.pump(KkSecretText.perChar * 3);
    expect(_shown(tester), 'abcde•••');
    await tester.pumpAndSettle();
    expect(_shown(tester), '•' * KkSecretText.concealedLength);
  });

  testWidgets('100 karakterde de toplam süre en çok 300 ms', (tester) async {
    final long = 'x' * 100;
    await tester.pumpWidget(_host(long, revealed: false));
    await tester.pumpWidget(_host(long, revealed: true));
    await tester.pump();
    await tester.pump(KkSecretText.maxTotal);
    expect(_shown(tester), long);
  });

  testWidgets('animasyonlar kapalıyken anında', (tester) async {
    await tester.pumpWidget(_host('abcdefgh', revealed: false, disable: true));
    await tester.pumpWidget(_host('abcdefgh', revealed: true, disable: true));
    await tester.pump();
    expect(_shown(tester), 'abcdefgh');
  });
}
