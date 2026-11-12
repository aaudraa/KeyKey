import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/generator/application/password_generator.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/add_flow.dart';
import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeLoginRepository logins;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    logins = FakeLoginRepository();
  });

  Future<void> openGenerator(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      logins: logins,
    );
    await openAddPassword(tester);
    await tester.tap(find.text('Üret'));
    await tester.pumpAndSettle();
  }

  String generated(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('generator-value'))).data!;

  testWidgets('üretilen parola forma geliyor ve gücü gösteriliyor', (
    tester,
  ) async {
    await openGenerator(tester);
    final value = generated(tester);
    expect(value, hasLength(const PasswordOptions().length));

    await tester.ensureVisible(find.text('Bunu kullan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bunu kullan'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Parola'),
    );
    expect(field.controller?.text, value);
    expect(find.textContaining('Güçlü'), findsOneWidget);
  });

  testWidgets('yeniden üret farklı parola veriyor', (tester) async {
    await openGenerator(tester);
    final first = generated(tester);

    await tester.tap(find.byTooltip('Yeniden üret'));
    await tester.pump();

    expect(generated(tester), isNot(first));
  });

  testWidgets('parola cümlesi seçilebiliyor', (tester) async {
    await openGenerator(tester);

    await tester.tap(find.text('Parola cümlesi'));
    await tester.pumpAndSettle();

    final phrase = generated(tester);
    expect(phrase, matches(RegExp(r'^[a-z]+(-[a-z]+){5,}$')));
    expect(find.text('Yaklaşık 78 bit rastgelelik'), findsOneWidget);
  });

  testWidgets('bütün sınıflar kapanırsa uyarı çıkıyor', (tester) async {
    await openGenerator(tester);

    for (final label in [
      'Küçük harfler',
      'Büyük harfler',
      'Rakamlar',
      'İşaretler',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    expect(find.text('En az bir karakter türü seç.'), findsOneWidget);
    final use = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Bunu kullan'),
    );
    expect(use.onPressed, isNull);
  });

  testWidgets('vazgeçince form değişmiyor', (tester) async {
    await openGenerator(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Parola'),
    );
    expect(field.controller?.text, isEmpty);
  });
}
