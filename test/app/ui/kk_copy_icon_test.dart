import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_copy_icon.dart';

Widget _host(Future<bool> Function() onCopy) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Center(
      child: KkCopyIcon(tooltip: 'Kopyala', onCopy: onCopy),
    ),
  ),
);

void main() {
  testWidgets('kopyalanınca simge onay işaretine döner, 1 sn sonra geri', (
    tester,
  ) async {
    var copies = 0;
    await tester.pumpWidget(
      _host(() async {
        copies++;
        return true;
      }),
    );
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Kopyala'));
    await tester.pumpAndSettle();
    expect(copies, 1);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pump(KkCopyIcon.hold);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('onay görünürken yeniden basmak yeniden kopyalar, süre baştan', (
    tester,
  ) async {
    var copies = 0;
    await tester.pumpWidget(
      _host(() async {
        copies++;
        return true;
      }),
    );
    await tester.tap(find.byTooltip('Kopyala'));
    await tester.pump();
    await tester.pump(KkCopyIcon.hold ~/ 2);
    await tester.tap(find.byTooltip('Kopyala'));
    await tester.pump();
    expect(copies, 2);
    await tester.pump(KkCopyIcon.hold * 0.75);
    // İlk basıştan beri 1 sn geçti ama süre ikinci basışla yenilendi.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
    await tester.pump(KkCopyIcon.hold * 0.5);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('kopyalanamadıysa (kasa kilitli) onay görünmez', (tester) async {
    await tester.pumpWidget(_host(() async => false));
    await tester.tap(find.byTooltip('Kopyala'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });
}
