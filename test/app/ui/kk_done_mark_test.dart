import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_done_mark.dart';
import 'package:keykey/app/ui/kk_motion.dart';

Widget _host({VoidCallback? onDone, bool disableAnimations = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Center(
          child: KkDoneMark(semanticLabel: 'Kaydedildi', onDone: onDone),
        ),
      ),
    );

double _progress(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(KkDoneMark),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as KkDoneMarkPainter)
        .progress;

void main() {
  testWidgets('onay işareti çizilerek belirir, bitince onDone bir kez', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(_host(onDone: () => done++));
    expect(_progress(tester), 0);
    await tester.pump(KkMotion.emphasis ~/ 4);
    expect(_progress(tester), greaterThan(0));
    expect(_progress(tester), lessThan(1));
    expect(done, 0);
    await tester.pumpAndSettle();
    expect(_progress(tester), 1);
    expect(done, 1);
    expect(find.bySemanticsLabel('Kaydedildi'), findsOneWidget);
  });

  testWidgets('animasyonlar kapalıyken hemen tam görünür, onDone çağrılır', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      _host(onDone: () => done++, disableAnimations: true),
    );
    await tester.pump();
    expect(_progress(tester), 1);
    expect(done, 1);
  });
}
