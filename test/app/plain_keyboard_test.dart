import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:sodium/sodium_sumo.dart';

import '../support/fake_vault_service.dart';

/// Gizli olmayan kutularda normal klavye ayarı (güvenlik tasarımı, "Arayüz
/// koruması"). Kutular gerçek formlarda, etiketleriyle bulunur.
void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  Future<void> open(
    WidgetTester tester,
    String route, {
    required bool plain,
  }) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      settings: FakeSettingsRepository(
        AppSettings.defaults.copyWith(plainKeyboard: plain),
      ),
    );
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
    await tester.pumpAndSettle();
  }

  TextField field(WidgetTester tester, String label) => tester.widget(
    find.ancestor(of: find.text(label), matching: find.byType(TextField)),
  );

  /// Kutunun klavyesi gizli kutu kuralına uyuyor: öneri, düzeltme ve
  /// öğrenme kapalı.
  void expectNoLearning(TextField f, String label) {
    expect(f.enableIMEPersonalizedLearning, isFalse, reason: label);
    expect(f.enableSuggestions, isFalse, reason: label);
    expect(f.autocorrect, isFalse, reason: label);
  }

  /// Normal klavyeli kutu: düzeltme ve öğrenme yine kapalı, ama öneri açık
  /// istenir. Flutter Android'de öneriyi kapatınca türü de görünür parolaya
  /// çeviriyor (TextInputPlugin); o zaman ne büyük harf ne adres tuşları
  /// gelir. Cihazda `dumpsys input_method` ile görüldü.
  void expectPlainLearning(TextField f, String label) {
    expect(f.enableIMEPersonalizedLearning, isFalse, reason: label);
    expect(f.enableSuggestions, isTrue, reason: label);
    expect(f.autocorrect, isFalse, reason: label);
  }

  void expectSecret(WidgetTester tester, String label) {
    final f = field(tester, label);
    expect(
      f.keyboardType,
      anyOf(
        TextInputType.visiblePassword,
        TextInputType.multiline,
        TextInputType.number,
        TextInputType.datetime,
      ),
      reason: label,
    );
    expect(f.textCapitalization, TextCapitalization.none, reason: label);
    expectNoLearning(f, label);
  }

  void expectPlainText(WidgetTester tester, String label) {
    final f = field(tester, label);
    expect(f.keyboardType, TextInputType.text, reason: label);
    expect(f.textCapitalization, TextCapitalization.words, reason: label);
    expectPlainLearning(f, label);
  }

  group('ayar açık', () {
    testWidgets('parola formunda ad normal, site adres klavyesi', (
      tester,
    ) async {
      await open(tester, AppRoutes.vaultNew, plain: true);
      expectPlainText(tester, 'Ad');
      final url = field(tester, 'Web adresi');
      expect(url.keyboardType, TextInputType.url);
      expectPlainLearning(url, 'Web adresi');
      for (final label in ['Kullanıcı adı', 'Parola']) {
        expectSecret(tester, label);
      }
    });

    testWidgets('kart formunda yalnızca ad ve klasör normal', (tester) async {
      await open(tester, AppRoutes.cardNew, plain: true);
      expectPlainText(tester, 'Ad');
      for (final label in ['Kart sahibi', 'Kart numarası']) {
        expectSecret(tester, label);
      }
    });

    testWidgets('not formunda metin gizli kalıyor', (tester) async {
      await open(tester, AppRoutes.noteNew, plain: true);
      expectPlainText(tester, 'Ad');
      expectSecret(tester, 'Metin');
    });

    testWidgets('2FA formunda servis normal, hesap gizli', (tester) async {
      await open(tester, AppRoutes.authenticatorNew, plain: true);
      expectPlainText(tester, 'Servis');
      expectSecret(tester, 'Hesap');
    });

    testWidgets('arama kutuları normal klavye', (tester) async {
      await open(tester, AppRoutes.vault, plain: true);
      final search = tester.widget<TextField>(find.byType(TextField).first);
      expect(search.keyboardType, TextInputType.text);
      expectPlainLearning(search, 'arama');
    });
  });

  testWidgets('ayar kapalıyken her kutu gizli klavye', (tester) async {
    await open(tester, AppRoutes.vaultNew, plain: false);
    for (final label in ['Ad', 'Web adresi', 'Kullanıcı adı', 'Parola']) {
      expectSecret(tester, label);
    }
  });
}
