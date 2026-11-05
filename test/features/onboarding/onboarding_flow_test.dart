import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  const password = 'kırmızı-Bisiklet-47-Deniz';
  const vaultText = 'Parolaların yakında burada olacak.';

  late SodiumSumo sodium;
  late FakeVaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  Future<void> pumpSetup(WidgetTester tester) =>
      pumpKeyKey(tester, status: const VaultNotSetUp(), service: service);

  FilledButton createButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Kasayı oluştur'));

  Future<void> typePasswords(
    WidgetTester tester,
    String first,
    String second,
  ) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), first);
    await tester.enterText(fields.at(1), second);
    await tester.pump();
  }

  Future<void> goToShowKey(WidgetTester tester) async {
    await pumpSetup(tester);
    await typePasswords(tester, password, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Kasayı oluştur'));
    await tester.pumpAndSettle();
  }

  Future<void> goToVerify(WidgetTester tester) async {
    await goToShowKey(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Yazdım'));
    await tester.pumpAndSettle();
  }

  Future<void> submitKey(WidgetTester tester, String key) async {
    await tester.enterText(find.byType(TextField), key);
    await tester.tap(find.widgetWithText(FilledButton, 'Doğrula ve kasayı aç'));
    await tester.pumpAndSettle();
  }

  group('ana parola adımı', () {
    testWidgets('geri alınamaz uyarısı görünüyor', (tester) async {
      await pumpSetup(tester);

      expect(find.textContaining('Arka kapı yok'), findsOneWidget);
    });

    testWidgets('kısa parolayla düğme kapalı', (tester) async {
      await pumpSetup(tester);

      await typePasswords(tester, 'kisa', 'kisa');

      expect(createButton(tester).onPressed, isNull);
      expect(find.textContaining('Çok kısa'), findsOneWidget);
    });

    testWidgets('parolalar farklıysa düğme kapalı ve uyarı var', (
      tester,
    ) async {
      await pumpSetup(tester);

      await typePasswords(tester, password, '$password-farkli');

      expect(createButton(tester).onPressed, isNull);
      expect(find.text('Parolalar aynı değil.'), findsOneWidget);
    });

    testWidgets('güç göstergesi parolaya göre değişiyor', (tester) async {
      await pumpSetup(tester);

      await typePasswords(tester, '1234567890', '');
      expect(find.textContaining('Zayıf'), findsOneWidget);

      await typePasswords(tester, password, '');
      expect(find.textContaining('Güçlü'), findsOneWidget);
    });

    testWidgets('zayıf ama kurala uyan parola uyarıyla kabul ediliyor', (
      tester,
    ) async {
      await pumpSetup(tester);

      await typePasswords(tester, '1234567890', '1234567890');

      expect(find.textContaining('Zayıf'), findsOneWidget);
      expect(createButton(tester).onPressed, isNotNull);
    });

    testWidgets('kutularda klavye öğrenmesi kapalı', (tester) async {
      await pumpSetup(tester);

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(2));
      for (final field in fields) {
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
        expect(field.enableIMEPersonalizedLearning, isFalse);
        expect(field.obscureText, isTrue);
      }
    });

    testWidgets('göster düğmesi parolayı açıyor', (tester) async {
      await pumpSetup(tester);

      await tester.tap(find.byTooltip('Göster').first);
      await tester.pump();

      final first = tester.widget<TextField>(find.byType(TextField).first);
      expect(first.obscureText, isFalse);
    });
  });

  group('kurtarma anahtarı', () {
    testWidgets('bir kez gösteriliyor, saklanmadığı söyleniyor', (
      tester,
    ) async {
      await goToShowKey(tester);

      expect(find.text(FakeVaultService.recoveryKey), findsOneWidget);
      expect(find.textContaining('KeyKey bunu saklamıyor'), findsOneWidget);
    });

    testWidgets('doğru yazılınca kasa açılıyor', (tester) async {
      await goToVerify(tester);

      await submitKey(tester, FakeVaultService.recoveryKey);

      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('yazım hatası içeri almıyor', (tester) async {
      await goToVerify(tester);

      await submitKey(tester, FakeVaultService.invalidRecoveryKey);

      expect(find.textContaining('yazım hatası'), findsOneWidget);
      expect(find.text(vaultText), findsNothing);
    });

    testWidgets('yanlış anahtar içeri almıyor, yeniden gösterilebiliyor', (
      tester,
    ) async {
      await goToVerify(tester);

      await submitKey(tester, 'ZZZZZ-ZZZZZ-ZZZZZ');
      expect(find.text('Bu, bu kasanın anahtarı değil.'), findsOneWidget);

      await tester.tap(find.text('Anahtarı yeniden göster'));
      await tester.pumpAndSettle();
      expect(find.text(FakeVaultService.recoveryKey), findsOneWidget);

      // Aynı kasa kullanılıyor, yeni kasa üretilmiyor.
      expect(service.prepareCount, 1);
    });

    testWidgets('anahtar kutusunda klavye öğrenmesi kapalı', (tester) async {
      await goToVerify(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
    });
  });
}
