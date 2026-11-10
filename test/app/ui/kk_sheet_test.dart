import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
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
  showKkConfirm(
    ctx,
    title: 'Silinsin mi?',
    message: 'Kayıt çöp kutusuna gider.',
    confirmLabel: 'Sil',
    cancelLabel: 'Vazgeç',
  ).then((value) => result = value);
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
    showKkConfirm(
      ctx,
      title: 'Silinsin mi?',
      message: 'Kayıt çöp kutusuna gider.',
      confirmLabel: 'Sil',
      cancelLabel: 'Vazgeç',
    ).then((value) => result = value);
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
    showKkConfirm(
      ctx,
      title: 'Silinsin mi?',
      message: 'm',
      confirmLabel: 'Sil',
      cancelLabel: 'Vazgeç',
    ).then((value) => result = value);
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
        home: Scaffold(
          body: KkSection(
            title: 'Güvenlik',
            children: const [Text('Bir'), Text('İki')],
          ),
        ),
      ),
    );
    expect(find.text('Güvenlik'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Bir'), matching: find.byType(Card)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('İki'), matching: find.byType(Card)),
      findsOneWidget,
    );
  });
}
