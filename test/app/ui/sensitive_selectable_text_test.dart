import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/sensitive_selectable_text.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

import '../../support/fake_vault_service.dart';

/// Gerçek pano gibi bir sonraki kareden sonra biten kopyalama.
class _SlowClipboard implements SensitiveClipboard {
  final pending = <Completer<void>>[];

  @override
  Future<void> copy(String text) {
    final done = Completer<void>();
    pending.add(done);
    return done.future;
  }
}

void main() {
  late SensitiveClipboard clipboard;
  late List<MethodCall> platformCalls;

  setUp(() {
    clipboard = RecordingClipboard();
    platformCalls = [];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
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
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: SensitiveSelectableText('kapi kodu 4821')),
          ),
        ),
      ),
    );
  }

  testWidgets('seçim menüsünde yalnızca kopyala ve tümünü seç var', (
    tester,
  ) async {
    await pump(tester);

    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();

    final buttons = tester
        .widgetList<TextSelectionToolbarTextButton>(
          find.byType(TextSelectionToolbarTextButton),
        )
        .map((button) => (button.child as Text).data)
        .toList();
    expect(buttons, unorderedEquals(['Kopyala', 'Tümünü seç']));
  });

  testWidgets('kopyala seçili parçayı hassas panoya yazar, sistem panosuna '
      'yazmaz', (tester) async {
    await pump(tester);

    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümünü seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopyala'));
    await tester.pumpAndSettle();

    expect((clipboard as RecordingClipboard).copied, ['kapi kodu 4821']);
    expect(
      platformCalls.where((call) => call.method == 'Clipboard.setData'),
      isEmpty,
    );
    expect(find.byType(TextSelectionToolbarTextButton), findsNothing);
  });

  testWidgets('kopyalama bitince bildirim çıkar', (tester) async {
    final slow = clipboard = _SlowClipboard();
    await pump(tester);

    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümünü seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopyala'));
    // Menü kapanıyor; pano ancak sonra yanıt veriyor.
    await tester.pumpAndSettle();
    slow.pending.single.complete();
    await tester.pumpAndSettle();

    expect(
      find.text('Kopyalandı. Pano 30 saniye sonra temizlenecek.'),
      findsOneWidget,
    );
  });
}
