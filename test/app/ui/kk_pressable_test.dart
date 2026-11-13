import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_pressable.dart';

double _scale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  test('kart %96,5, küçük düğme %88', () {
    expect(KkPressable.cardScale, 0.965);
    expect(KkPressable.smallScale, 0.88);
  });

  testWidgets('basılıyken esner, bırakınca yaylanarak döner; dokunuş bir kez', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: KkPressable(
            pressedScale: KkPressable.smallScale,
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.add)),
    );
    await tester.pump();
    expect(_scale(tester), KkPressable.smallScale);
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, KkMotion.fast);
    expect(scale.curve, KkMotion.spring);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
    expect(taps, 1);
  });

  testWidgets('kaydırma basma sayılmaz', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              KkPressable(
                child: SizedBox(
                  height: 60,
                  child: InkWell(onTap: () {}, child: const Text('kart')),
                ),
              ),
              for (var i = 0; i < 30; i++)
                SizedBox(height: 60, child: Text('satır $i')),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('kart')),
    );
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(_scale(tester), 1);
    await gesture.up();
  });
}
