import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_motion.dart';
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

const _topPadding = 24.0;

Future<(BuildContext, WidgetRef)> _pump(
  WidgetTester tester,
  _Clipboard clipboard, {
  bool accessibleNavigation = false,
  bool disableAnimations = false,
}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: _topPadding),
            accessibleNavigation: accessibleNavigation,
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
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
  tearDown(hideKkSnack);

  testWidgets('ikinci bildirim birincinin yerini alır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pump();
    showKkSnack(ctx, 'iki');
    await tester.pumpAndSettle();
    expect(find.byType(KkSnack), findsOneWidget);
    expect(find.text('iki'), findsOneWidget);
    expect(find.text('bir'), findsNothing);
  });

  testWidgets('bildirim cam: arkasını bulanıklaştırır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(KkSnack),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('bildirim üstte ve ortada', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'Kopyalandı');
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(KkSnack.pillKey));
    expect(rect.top, greaterThanOrEqualTo(_topPadding + 8));
    expect(rect.top, lessThan(200));
    expect(rect.center.dx, closeTo(200, 1));
    expect(rect.width, lessThan(400 - 32));
  });

  testWidgets('yazı 16 punto ve kalın', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'Kopyalandı');
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Kopyalandı'));
    expect(text.style?.fontSize, 16);
    expect(text.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('uzun mesaj satıra iner, kenarlardan taşmaz', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'uzun ' * 40);
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(KkSnack.pillKey));
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(400 - 16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('düğmesiz bildirim 4 saniyede kapanır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.byType(KkSnack), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(KkSnack), findsNothing);
  });

  testWidgets('düğmeli bildirim 6 saniye kalır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(
      ctx,
      'bir',
      action: KkSnackAction(label: 'Geri al', onPressed: () {}),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 5900));
    expect(find.byType(KkSnack), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(KkSnack), findsNothing);
  });

  testWidgets('düğme bir kez çalışır ve bildirimi kapatır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    var pressed = 0;
    showKkSnack(
      ctx,
      'bir',
      action: KkSnackAction(label: 'Geri al', onPressed: () => pressed++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
    expect(find.byType(KkSnack), findsNothing);
  });

  testWidgets('TalkBack açıkken düğmeli bildirim kendiliğinden kapanmaz', (
    tester,
  ) async {
    final (ctx, _) = await _pump(
      tester,
      _Clipboard(),
      accessibleNavigation: true,
    );
    showKkSnack(
      ctx,
      'bir',
      action: KkSnackAction(label: 'Geri al', onPressed: () {}),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.byType(KkSnack), findsOneWidget);
  });

  testWidgets('yukarı kaydırınca kapanır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(KkSnack.pillKey), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(find.byType(KkSnack), findsNothing);
  });

  testWidgets('eskinin zamanlayıcısı yenisini kapatmaz', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    showKkSnack(ctx, 'iki');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('iki'), findsOneWidget);
  });

  testWidgets('ekran kapansa da bildirim kalır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    late BuildContext pageContext;
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (context) {
          pageContext = context;
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pumpAndSettle();
    showKkSnack(pageContext, 'Çöpe taşındı');
    Navigator.of(pageContext).pop();
    await tester.pumpAndSettle();
    expect(find.text('Çöpe taşındı'), findsOneWidget);
  });

  testWidgets('alt pencere açıkken bildirim pencerenin üstünde', (
    tester,
  ) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pumpAndSettle();
    unawaited(
      showModalBottomSheet<void>(
        context: ctx,
        builder: (_) => const SizedBox(height: 800),
        isScrollControlled: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(KkSnack.pillKey).hitTestable(), findsOneWidget);
  });

  testWidgets('hideKkSnack bildirimi kapatır', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard());
    showKkSnack(ctx, 'bir');
    await tester.pumpAndSettle();
    hideKkSnack();
    await tester.pumpAndSettle();
    expect(find.byType(KkSnack), findsNothing);
  });

  testWidgets('animasyonlar kapalıyken anında yerinde', (tester) async {
    final (ctx, _) = await _pump(tester, _Clipboard(), disableAnimations: true);
    showKkSnack(ctx, 'bir');
    await tester.pump();
    await tester.pump();
    final rect = tester.getRect(find.byKey(KkSnack.pillKey));
    expect(rect.top, greaterThanOrEqualTo(_topPadding + 8));
    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(KkSnack.pillKey),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1);
  });

  test('süreler KkMotion içinde', () {
    expect(KkMotion.snack, const Duration(seconds: 4));
    expect(KkMotion.snackWithAction, const Duration(seconds: 6));
  });

  testWidgets('copySensitive kopyalar ve bildirir', (tester) async {
    final clipboard = _Clipboard();
    final (ctx, ref) = await _pump(tester, clipboard);
    expect(await copySensitive(ctx, ref, 'gizli'), isTrue);
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
    expect(await copySensitive(ctx, ref, 'gizli'), isFalse);
    await tester.pumpAndSettle();
    expect(clipboard.copied, isEmpty);
    expect(find.byType(KkSnack), findsNothing);
  });
}
