import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

class _Clipboard implements SensitiveClipboard {
  final copied = <String>[];
  bool locked = false;

  @override
  Future<void> copy(String text) async {
    if (locked) throw const VaultLockedException();
    copied.add(text);
  }
}

Future<(BuildContext, WidgetRef)> _pump(
  WidgetTester tester,
  _Clipboard clipboard,
) async {
  late BuildContext ctx;
  late WidgetRef widgetRef;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sensitiveClipboardProvider.overrideWithValue(clipboard)],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            ctx = context;
            widgetRef = ref;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    ),
  );
  return (ctx, widgetRef);
}

void main() {
  testWidgets('ikinci bildirim birincinin yerini alır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pump();
    showKkSnack(ctx, 'iki');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('iki'), findsOneWidget);
    expect(find.text('bir'), findsNothing);
  });

  testWidgets('bildirim cam: arkasını bulanıklaştırır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('copySensitive kopyalar ve bildirir', (tester) async {
    final clipboard = _Clipboard();
    final (ctx, ref) = await _pump(tester, clipboard);
    await copySensitive(ctx, ref, 'gizli');
    await tester.pumpAndSettle();
    expect(clipboard.copied, ['gizli']);
    expect(
      find.text('Kopyalandı. Pano 30 saniye sonra temizlenecek.'),
      findsOneWidget,
    );
  });

  testWidgets('kasa kilitlenmişse hata fırlamaz, bildirim çıkmaz', (
    tester,
  ) async {
    final clipboard = _Clipboard()..locked = true;
    final (ctx, ref) = await _pump(tester, clipboard);
    await copySensitive(ctx, ref, 'gizli');
    await tester.pumpAndSettle();
    expect(clipboard.copied, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });
}
