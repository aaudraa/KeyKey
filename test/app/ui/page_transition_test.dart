import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_motion.dart';

void main() {
  test('tema tahmini geri hareketini korur (madde 1.4, kural 7)', () {
    // Kök gezgindeki sayfalarda parmağı izler; sekme sayfalarında hareket
    // yönlendiriciye düşer (#173, S1).
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<RootPredictiveBackTransitions>(),
      );
    }
  });

  test('geçiş süresi tahmini geri geçişininki gibi kalıyor', () {
    // S1 düzeltmesi geçişi değiştirmemeli; MaterialPage süreyi temadaki
    // kurucudan alır.
    const predictive = PredictiveBackPageTransitionsBuilder();
    const builder = RootPredictiveBackTransitions();
    expect(builder.transitionDuration, predictive.transitionDuration);
    expect(
      builder.reverseTransitionDuration,
      predictive.reverseTransitionDuration,
    );
  });

  testWidgets('yeni sayfa sağdan kayarak açılır', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('yeni')),
              ),
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(KkMotion.enter ~/ 2);
    expect(tester.getTopLeft(find.text('yeni')).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('yeni')).dx, 0);
  });
}
