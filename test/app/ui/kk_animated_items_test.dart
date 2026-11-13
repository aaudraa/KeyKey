import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_animated_items.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Öğe: 40 dp yüksekliğinde bir yazı.
class _Row extends StatelessWidget {
  const new(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 40, child: Text(label));
}

Widget _host(List<String> items, {bool disableAnimations = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              KkAnimatedItems<String>(
                items: items,
                keyOf: (item) => item,
                itemBuilder: (context, item, index) => _Row(item),
              ),
            ],
          ),
        ),
      ),
    );

double _opacity(WidgetTester tester, String label) => tester
    .widget<FadeTransition>(
      find
          .ancestor(of: find.text(label), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

double _slotHeight(WidgetTester tester, String label) => tester
    .getSize(
      find
          .ancestor(of: find.text(label), matching: find.byType(SizeTransition))
          .first,
    )
    .height;

void main() {
  testWidgets('çıkan öğe sola kayıp solar, yüksekliği kapanır, sonra yok', (
    tester,
  ) async {
    await tester.pumpWidget(_host(['a', 'b', 'c']));
    await tester.pumpWidget(_host(['a', 'c']));
    await tester.pump();
    await tester.pump(KkMotion.base ~/ 2);
    expect(find.text('b'), findsOneWidget);
    expect(_opacity(tester, 'b'), lessThan(1));
    final slide = tester
        .widget<Transform>(
          find
              .ancestor(of: find.text('b'), matching: find.byType(Transform))
              .first,
        )
        .transform
        .storage[12];
    expect(slide, lessThan(0));
    await tester.pump(KkMotion.base);
    expect(find.text('b'), findsNothing);
    // Alttaki öğe yukarı kaydı.
    expect(
      tester.getTopLeft(find.text('c')).dy,
      tester.getTopLeft(find.text('a')).dy + 40 + KkAnimatedItems.gap,
    );
  });

  testWidgets('giren öğe solarak ve yükseklik açarak gelir', (tester) async {
    await tester.pumpWidget(_host(['a', 'c']));
    await tester.pumpWidget(_host(['a', 'b', 'c']));
    await tester.pump();
    await tester.pump(KkMotion.base ~/ 2);
    expect(_slotHeight(tester, 'b'), greaterThan(0));
    expect(_slotHeight(tester, 'b'), lessThan(40 + KkAnimatedItems.gap));
    expect(_opacity(tester, 'b'), lessThan(1));
    await tester.pumpAndSettle();
    expect(_slotHeight(tester, 'b'), 40 + KkAnimatedItems.gap);
  });

  testWidgets('yer değiştirince yeni sırayla yerleşir', (tester) async {
    await tester.pumpWidget(_host(['a', 'b', 'c']));
    await tester.pumpWidget(_host(['c', 'b', 'a']));
    await tester.pumpAndSettle();
    final ys = [
      for (final label in ['c', 'b', 'a'])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(ys[0], lessThan(ys[1]));
    expect(ys[1], lessThan(ys[2]));
  });

  testWidgets('1000 öğede yalnızca görünenler kurulur', (tester) async {
    final items = [for (var i = 0; i < 1000; i++) 'öğe $i'];
    await tester.pumpWidget(_host(items));
    expect(find.byType(_Row).evaluate().length, lessThan(30));
    await tester.pumpWidget(_host(items.sublist(1)));
    await tester.pumpAndSettle();
    expect(find.byType(_Row).evaluate().length, lessThan(30));
    expect(find.text('öğe 0'), findsNothing);
  });

  testWidgets('animasyonlar kapalıyken değişim anında', (tester) async {
    await tester.pumpWidget(_host(['a', 'b', 'c'], disableAnimations: true));
    await tester.pumpWidget(_host(['a', 'c'], disableAnimations: true));
    await tester.pump();
    expect(find.text('b'), findsNothing);
    await tester.pumpWidget(_host(['a', 'b', 'c'], disableAnimations: true));
    await tester.pump();
    expect(_slotHeight(tester, 'b'), 40 + KkAnimatedItems.gap);
  });
}
