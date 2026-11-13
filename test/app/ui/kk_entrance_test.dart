import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_entrance.dart';
import 'package:keykey/app/ui/kk_motion.dart';

double _opacity(WidgetTester tester, String text) {
  final fade = tester.widget<Opacity>(
    find.ancestor(of: find.text(text), matching: find.byType(Opacity)).last,
  );
  return fade.opacity;
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

Matrix4 _transform(WidgetTester tester, String text) => tester
    .widget<Transform>(
      find
          .ancestor(of: find.text(text), matching: find.byType(Transform))
          .first,
    )
    .transform;

Widget _list(int count) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: KkEntranceScope(
      child: ListView(
        children: [
          for (var i = 0; i < count; i++)
            KkEntrance(
              index: i,
              child: SizedBox(height: 60, child: Text('öğe $i')),
            ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('ilk karede kurulan öğeler sırayla belirir', (tester) async {
    await tester.pumpWidget(const _Grow(disable: false));
    expect(_opacity(tester, 'öğe 0'), lessThan(1));
    await tester.pump(KkMotion.enter + const Duration(milliseconds: 400));
    expect(_opacity(tester, 'öğe 0'), 1);
  });

  testWidgets('ilk karedeki bütün öğeler belirir, dokuzuncu ve sonrası da', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: KkEntranceScope(
            child: ListView(
              children: [
                for (var i = 0; i < 14; i++)
                  KkEntrance(index: i, child: Text('öğe $i')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(_opacity(tester, 'öğe 8'), lessThan(1));
    expect(_opacity(tester, 'öğe 13'), lessThan(1));
    // Gecikme sekizinci öğede durur: sonrakiler onunla birlikte gelir,
    // liste uzun da olsa giriş yarım saniyeyi aşmaz.
    await tester.pump(
      KkEntrance.step * KkEntrance.maxStaggered + KkMotion.enter,
    );
    expect(_opacity(tester, 'öğe 13'), 1);
  });

  testWidgets('giriş 16 dp aşağıdan ve %96 ölçekten, 350 ms', (tester) async {
    await tester.pumpWidget(_list(3));
    final first = _transform(tester, 'öğe 0');
    expect(first.storage[13], closeTo(16, 0.01));
    expect(first.storage[0], closeTo(0.96, 0.001));
    await tester.pump(KkMotion.enter ~/ 2);
    expect(_opacity(tester, 'öğe 0'), lessThan(1));
    await tester.pump(KkMotion.enter ~/ 2);
    expect(_opacity(tester, 'öğe 0'), 1);
    expect(_transform(tester, 'öğe 0').storage[13], closeTo(0, 0.01));
  });

  testWidgets('kaydırınca ekrana giren öğe de belirerek gelir', (tester) async {
    await tester.pumpWidget(_list(80));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pump();
    final newcomer = find.text('öğe 30');
    expect(newcomer, findsOneWidget);
    expect(_opacity(tester, 'öğe 30'), lessThan(1));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'öğe 30'), 1);
  });

  testWidgets('sekmeye dönünce (TickerMode) giriş yeniden oynar', (
    tester,
  ) async {
    final active = ValueNotifier(true);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: active,
        builder: (context, on, _) => TickerMode(enabled: on, child: _list(3)),
      ),
    );
    await tester.pumpAndSettle();
    active.value = false;
    await tester.pump();
    active.value = true;
    await tester.pump();
    expect(_opacity(tester, 'öğe 0'), lessThan(1));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'öğe 0'), 1);
  });

  testWidgets('alt ekrandan geri dönünce giriş yeniden oynar', (tester) async {
    await tester.pumpWidget(_list(3));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator))
      ..push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_opacity(tester, 'öğe 0'), lessThan(1));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'öğe 0'), 1);
  });

  testWidgets('animasyonlar kapalıyken yeniden oynama da yok', (tester) async {
    final active = ValueNotifier(true);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (context, on, _) => TickerMode(enabled: on, child: _list(3)),
        ),
      ),
    );
    active.value = false;
    await tester.pump();
    active.value = true;
    await tester.pump();
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
