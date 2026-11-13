import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_shake.dart';

/// Titreşim çağrılarını sayar.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

double _dx(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(of: find.text('alan'), matching: find.byType(Transform))
          .first,
    )
    .transform
    .storage[12];

Widget _host(
  KkShakeController controller, {
  bool enabled = true,
  bool disableAnimations = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Center(
      child: KkShake(
        controller: controller,
        enabled: enabled,
        child: const Text('alan'),
      ),
    ),
  ),
);

void main() {
  testWidgets('üç kısa salınımla titrer, hafif titreşimle', (tester) async {
    final haptics = _recordHaptics(tester);
    final controller = KkShakeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    expect(_dx(tester), 0);
    controller.shake();
    await tester.pump();
    await tester.pump(KkMotion.shake ~/ 4);
    expect(_dx(tester).abs(), greaterThan(0.5));
    expect(_dx(tester).abs(), lessThanOrEqualTo(8));
    await tester.pump(KkMotion.shake);
    expect(_dx(tester), 0);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('animasyonlar kapalıyken kıpırdamaz, titreşim yine var', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    final controller = KkShakeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, disableAnimations: true));
    controller.shake();
    await tester.pump();
    await tester.pump(KkMotion.shake ~/ 4);
    expect(_dx(tester), 0);
    expect(haptics, hasLength(1));
  });

  testWidgets('hatası olmayan alan (enabled: false) titremez; titreşim '
      'denetleyiciden bir kez', (tester) async {
    final haptics = _recordHaptics(tester);
    final controller = KkShakeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, enabled: false));
    controller.shake();
    await tester.pump();
    await tester.pump(KkMotion.shake ~/ 4);
    expect(_dx(tester), 0);
    expect(haptics, hasLength(1));
  });
}
