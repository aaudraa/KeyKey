import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_motion.dart';

void main() {
  test('tema tahmini geri hareketini korur (madde 1.4, kural 7)', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
    }
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
