import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_entrance.dart';
import 'package:keykey/app/ui/kk_motion.dart';

double _opacity(WidgetTester tester, String text) {
  final fade = tester.widget<FadeTransition>(
    find
        .ancestor(of: find.text(text), matching: find.byType(FadeTransition))
        .first,
  );
  return fade.opacity.value;
}

class _Grow extends StatefulWidget {
  const new({required this.disable});

  final bool disable;

  @override
  State<_Grow> createState() => _GrowState();
}

class _GrowState extends State<_Grow> {
  int count = 1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: widget.disable),
        child: Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => setState(() => count++),
            child: const Icon(Icons.add),
          ),
          body: KkEntranceScope(
            child: Column(
              children: [
                for (var i = 0; i < count; i++)
                  KkEntrance(index: i, child: Text('öğe $i')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('ilk karede kurulan öğeler sırayla belirir', (tester) async {
    await tester.pumpWidget(const _Grow(disable: false));
    expect(_opacity(tester, 'öğe 0'), lessThan(1));
    await tester.pump(KkMotion.base + const Duration(milliseconds: 400));
    expect(_opacity(tester, 'öğe 0'), 1);
  });

  testWidgets('sonradan kurulan öğe hareketsiz, hemen görünür', (tester) async {
    await tester.pumpWidget(const _Grow(disable: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(_opacity(tester, 'öğe 1'), 1);
  });

  testWidgets('animasyonlar kapalıyken her şey ilk karede görünür', (
    tester,
  ) async {
    await tester.pumpWidget(const _Grow(disable: true));
    expect(_opacity(tester, 'öğe 0'), 1);
  });

  testWidgets('kapsam dışındaki öğe hemen görünür', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: KkEntrance(index: 0, child: Text('tek'))),
    );
    expect(_opacity(tester, 'tek'), 1);
  });
}
