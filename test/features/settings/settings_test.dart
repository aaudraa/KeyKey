import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  const newPassword = 'yepyeni-Ana-Parola-58';

  late SodiumSumo sodium;
  late FakeVaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> openChangePassword(WidgetTester tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Ana parolayı değiştir'));
    await tester.pumpAndSettle();
  }

  Future<void> submitChange(
    WidgetTester tester, {
    required String current,
    String next = newPassword,
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), next);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Parolayı değiştir'));
    await tester.pumpAndSettle();
  }

  testWidgets('şimdi kilitle kasayı kilitliyor', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Şimdi kilitle'));
    await tester.pumpAndSettle();

    expect(find.text('KeyKey kilitli'), findsOneWidget);
  });

  testWidgets('doğru mevcut parolayla parola değişiyor', (tester) async {
    await openChangePassword(tester);

    await submitChange(tester, current: FakeVaultService.correctPassword);

    expect(service.changedPassword, newPassword);
    expect(find.text('Ana parola değiştirildi.'), findsOneWidget);
    expect(find.text('Şimdi kilitle'), findsOneWidget);
  });

  testWidgets('mevcut parola yanlışsa değişmiyor', (tester) async {
    await openChangePassword(tester);

    await submitChange(tester, current: 'yanlis-parola-99');

    expect(service.changedPassword, isNull);
    expect(find.text('Parola yanlış.'), findsOneWidget);
    expect(find.text('Ana parolayı değiştir'), findsOneWidget);
  });

  testWidgets('kısa yeni parolayla düğme kapalı', (tester) async {
    await openChangePassword(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), FakeVaultService.correctPassword);
    await tester.enterText(fields.at(1), 'kisa');
    await tester.enterText(fields.at(2), 'kisa');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Parolayı değiştir'),
    );
    expect(button.onPressed, isNull);
  });
}
