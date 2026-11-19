import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

import '../support/fake_vault_service.dart';

void main() {
  late RecordingClipboard clipboard;
  late List<MethodCall> platformCalls;
  late TextEditingController controller;
  late List<String> changes;

  setUp(() {
    clipboard = RecordingClipboard();
    platformCalls = [];
    controller = TextEditingController(text: 'kapi kodu 4821');
    changes = [];
  });

  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, {bool obscure = false}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        // Panoda metin var: "Yapıştır" da görünsün.
        if (call.method == 'Clipboard.hasStrings') {
          return {'value': true};
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sensitiveClipboardProvider.overrideWithValue(clipboard)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SecretField(
                controller: controller,
                label: 'Not',
                obscure: obscure,
                initiallyVisible: obscure,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> selectAll(WidgetTester tester) async {
    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümünü seç'));
    await tester.pumpAndSettle();
  }

  Iterable<MethodCall> systemCopies() =>
      platformCalls.where((call) => call.method == 'Clipboard.setData');

  testWidgets('kopyala hassas panoya yazar, sistem panosuna yazmaz', (
    tester,
  ) async {
    await pump(tester);
    await selectAll(tester);

    await tester.tap(find.text('Kopyala'));
    await tester.pumpAndSettle();

    expect(clipboard.copied, ['kapi kodu 4821']);
    expect(systemCopies(), isEmpty);
    expect(controller.text, 'kapi kodu 4821');
    expect(
      find.text('Kopyalandı. Pano 30 saniye sonra temizlenecek.'),
      findsOneWidget,
    );
  });

  testWidgets('kes hassas panoya yazar ve metni siler', (tester) async {
    await pump(tester);
    await selectAll(tester);

    await tester.tap(find.text('Kes'));
    await tester.pumpAndSettle();

    expect(clipboard.copied, ['kapi kodu 4821']);
    expect(systemCopies(), isEmpty);
    expect(controller.text, isEmpty);
    expect(changes, ['']);
  });

  testWidgets('açılmış gizli kutuda da kopyalama hassas panodan geçer', (
    tester,
  ) async {
    await pump(tester, obscure: true);
    await selectAll(tester);

    await tester.tap(find.text('Kopyala'));
    await tester.pumpAndSettle();

    expect(clipboard.copied, ['kapi kodu 4821']);
    expect(systemCopies(), isEmpty);
  });

  testWidgets('menüde metni başka uygulamaya gönderen düğme yok', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pump(tester);
      await tester.longPress(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tümünü Seç'));
      await tester.pumpAndSettle();

      expect(find.text('Kopyala'), findsOneWidget);
      for (final label in ['Paylaş...', 'Ara', "Web'de Ara"]) {
        expect(find.text(label), findsNothing, reason: label);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
