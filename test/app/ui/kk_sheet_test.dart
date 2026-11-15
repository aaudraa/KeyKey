import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/ui/kk_sheet.dart';

/// Onay penceresini açar; dönen fonksiyon o anki sonucu verir.
Future<bool? Function()> _openConfirm(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) {
          ctx = context;
          return const Scaffold();
        },
      ),
    ),
  );
  bool? result;
  unawaited(
    showKkConfirm(
      ctx,
      title: 'Silinsin mi?',
      message: 'Kayıt çöp kutusuna gider.',
      confirmLabel: 'Sil',
      cancelLabel: 'Vazgeç',
    ).then((value) => result = value),
  );
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('onay penceresi alttan açılır, onaylanınca true', (tester) async {
    bool? result;
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showKkConfirm(
        ctx,
        title: 'Silinsin mi?',
        message: 'Kayıt çöp kutusuna gider.',
        confirmLabel: 'Sil',
        cancelLabel: 'Vazgeç',
      ).then((value) => result = value),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Kayıt çöp kutusuna gider.'), findsOneWidget);
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('vazgeçilince false', (tester) async {
    bool? result;
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showKkConfirm(
        ctx,
        title: 'Silinsin mi?',
        message: 'm',
        confirmLabel: 'Sil',
        cancelLabel: 'Vazgeç',
      ).then((value) => result = value),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('dışına dokunup kapatınca false', (tester) async {
    final result = await _openConfirm(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(result(), isFalse);
  });

  testWidgets('bölüm başlığı ve satırları tek kartta', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: KkSection(
            title: 'Güvenlik',
            children: [Text('Bir'), Text('İki')],
          ),
        ),
      ),
    );
    expect(find.text('Güvenlik'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Bir'), matching: find.byType(GlassSurface)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('İki'), matching: find.byType(GlassSurface)),
      findsOneWidget,
    );
  });

  testWidgets('pencere cam: arkasını bulanıklaştırır', (tester) async {
    await _openConfirm(tester);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('animasyonlar kapalıyken pencere hemen yerinde', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showKkConfirm(
        ctx,
        title: 'Silinsin mi?',
        confirmLabel: 'Sil',
        cancelLabel: 'Vazgeç',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Sil'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    final bottom = tester.getRect(find.text('Vazgeç')).bottom;
    expect(bottom, lessThan(600));
  });
}
