import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  const password = 'kırmızı-Bisiklet-47-Deniz';
  const vaultText =
      'Henüz kayıt yok. Parola, kart ya da not eklemek için '
      'alttaki + düğmesine dokun.';

  late SodiumSumo sodium;
  late FakeVaultService service;
  late RecordingClipboard clipboard;
  late FakeDocumentFiles documents;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    clipboard = RecordingClipboard();
    documents = FakeDocumentFiles();
  });

  Future<void> pumpSetup(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: const VaultNotSetUp(),
      service: service,
      clipboard: clipboard,
      documents: documents,
    );
    await skipIntro(tester);
  }

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
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydettim'));
    await tester.pumpAndSettle();
  }

  Future<void> submitKey(WidgetTester tester, String key) async {
    await tester.enterText(find.byType(TextField), key);
    await tester.tap(find.widgetWithText(FilledButton, 'Doğrula ve kasayı aç'));
    await tester.pumpAndSettle();
  }

  group('adım geçişi', () {
    /// Ekran okuyucunun gördüğü ağaçta bu etiket var mı.
    bool spoken(WidgetTester tester, String label) {
      var found = false;
      bool visit(SemanticsNode node) {
        if (node.label.contains(label)) found = true;
        node.visitChildren(visit);
        return !found;
      }

      visit(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      return found;
    }

    testWidgets('çıkan adım dokunuşa ve ekran okuyucuya kapalı', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await goToShowKey(tester);
      final keyText = find.byWidgetPredicate(
        (widget) => widget is Text && widget.style?.fontFamily == 'monospace',
      );
      final key = tester.widget<Text>(keyText).data!;
      expect(spoken(tester, key), isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydettim'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Kayıp giden adım hâlâ çiziliyor ama okunmuyor, dokunulmuyor.
      expect(keyText, findsOneWidget);
      expect(spoken(tester, key), isFalse);
      expect(
        find.ancestor(of: keyText, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      expect(
        tester
            .widgetList<IgnorePointer>(
              find.ancestor(of: keyText, matching: find.byType(IgnorePointer)),
            )
            .any((w) => w.ignoring),
        isTrue,
      );
      await tester.pumpAndSettle();
      handle.dispose();
    });

    double progress(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(
          find.descendant(
            of: find.byKey(OnboardingScreen.stepIndicatorKey),
            matching: find.byType(LinearProgressIndicator),
          ),
        )
        .value!;

    testWidgets('yeni adım yandan kayarak gelir, gösterge dolarak ilerler', (
      tester,
    ) async {
      await pumpSetup(tester);
      expect(progress(tester), closeTo(1 / 3, 0.001));
      await typePasswords(tester, password, password);
      await tester.tap(find.widgetWithText(FilledButton, 'Kasayı oluştur'));
      final next = find.widgetWithText(FilledButton, 'Kaydettim');
      for (var i = 0; i < 100 && next.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 50));
      final sliding = tester.getTopLeft(next).dx;
      final midway = progress(tester);
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(next).dx;
      expect(sliding, greaterThan(settled + 1));
      expect(midway, greaterThan(1 / 3));
      expect(midway, lessThan(2 / 3));
      expect(progress(tester), closeTo(2 / 3, 0.001));
    });
  });

  group('ana parola adımı', () {
    testWidgets('kurulumun ilk adımında logo var', (tester) async {
      await pumpSetup(tester);

      expect(find.bySemanticsLabel('KeyKey'), findsOneWidget);
    });

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

    testWidgets('tiresiz ve küçük harfle yazılan anahtar düzenleniyor', (
      tester,
    ) async {
      await goToVerify(tester);
      final plain = FakeVaultService.recoveryKey.replaceAll('-', '');

      await tester.enterText(find.byType(TextField), plain.toLowerCase());
      await tester.pump();
      expect(find.text(FakeVaultService.recoveryKey), findsOneWidget);
      expect(find.text('55/55 karakter'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Doğrula ve kasayı aç'),
      );
      await tester.pumpAndSettle();
      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('eksik anahtar uzunluğuyla söyleniyor', (tester) async {
      await goToVerify(tester);

      await submitKey(tester, 'AAAAA-BBBBB-CCCCC');

      expect(
        find.text('Anahtar 55 karakter, sen 15 karakter yazdın.'),
        findsOneWidget,
      );
      expect(find.text(vaultText), findsNothing);
    });

    testWidgets('yazım hatası içeri almıyor', (tester) async {
      await goToVerify(tester);

      await submitKey(tester, FakeVaultService.invalidRecoveryKey);

      expect(
        find.text(
          '11. grupta yazım hatası var. Ekrandaki ve kağıdındaki anahtarla '
          'karşılaştır.',
        ),
        findsOneWidget,
      );
      expect(find.text(vaultText), findsNothing);
    });

    testWidgets('yanlış anahtar içeri almıyor, yeniden gösterilebiliyor', (
      tester,
    ) async {
      await goToVerify(tester);

      await submitKey(tester, FakeVaultService.otherRecoveryKey);
      expect(find.textContaining('1. grupta yazım hatası'), findsOneWidget);

      await tester.tap(find.text('Anahtarı yeniden göster'));
      await tester.pumpAndSettle();
      expect(find.text(FakeVaultService.recoveryKey), findsOneWidget);

      // Aynı kasa kullanılıyor, yeni kasa üretilmiyor.
      expect(service.prepareCount, 1);
    });

    testWidgets('kopyala düğmesi anahtarı güvenli panoya koyuyor', (
      tester,
    ) async {
      await goToShowKey(tester);
      await tester.tap(find.text('Kopyala'));
      await tester.pump();
      expect(clipboard.copied, [FakeVaultService.recoveryKey]);
      await tester.pumpAndSettle();
    });

    testWidgets('anahtar metin dosyası olarak kaydediliyor', (tester) async {
      await goToShowKey(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Dosyaya kaydet')),
      );
      documents.readGate = () => container.read(externalActivityGateProvider);
      await tester.tap(find.text('Dosyaya kaydet'));
      await tester.pump();
      // Kurulumda kasa yok; seçici dış etkinlik kapısından geçmez.
      expect(documents.gateWasActive, isFalse);
      expect(documents.savedName, 'keykey-kurtarma-anahtari.txt');
      expect(
        utf8.decode(documents.savedBytes!),
        contains(FakeVaultService.recoveryKey),
      );
      expect(find.textContaining('telefonda bırakma'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('kaydedilemezse söyleniyor', (tester) async {
      documents.nextSave = DocumentSaveResult.failed;
      await goToShowKey(tester);
      await tester.tap(find.text('Dosyaya kaydet'));
      await tester.pump();
      expect(find.text('Dosya kaydedilemedi.'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('dosyadan okunan anahtarla kasa açılıyor', (tester) async {
      documents.nextOpen = DocumentOpened(
        Uint8List.fromList(
          utf8.encode(
            'KeyKey kurtarma anahtarı\n'
            '${FakeVaultService.recoveryKey.toLowerCase()}\n',
          ),
        ),
      );
      await goToVerify(tester);
      await tester.tap(find.text('Dosyadan oku'));
      await tester.pumpAndSettle();
      expect(find.text(FakeVaultService.recoveryKey), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Doğrula ve kasayı aç'),
      );
      await tester.pumpAndSettle();
      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('anahtar olmayan dosya söyleniyor', (tester) async {
      documents.nextOpen = DocumentOpened(
        Uint8List.fromList(utf8.encode('merhaba')),
      );
      await goToVerify(tester);
      await tester.tap(find.text('Dosyadan oku'));
      await tester.pump();
      expect(
        find.text('Dosyada kurtarma anahtarı bulunamadı.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.pumpAndSettle();
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
