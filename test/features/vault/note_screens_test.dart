import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/note_detail_screen.dart';
import 'package:keykey/features/vault/presentation/note_edit_screen.dart';
import 'package:keykey/features/vault/presentation/utf8_length_formatter.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeRecordRepository<NoteContent> notes;
  late RecordingClipboard clipboard;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    clipboard = RecordingClipboard();
    notes = FakeRecordRepository<NoteContent>(
      items: [
        FakeRecordRepository.item(
          NoteContent(name: 'Ev Wi-Fi', text: 'ağ: Ev\nparola: kirmizi-kapi'),
          id: 1,
        ),
      ],
    );
  });

  Future<void> pumpApp(WidgetTester tester) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
    notes: notes,
    clipboard: clipboard,
  );

  Future<void> go(WidgetTester tester, String location) async {
    unawaited(
      GoRouter.of(tester.element(find.byType(VaultScreen))).push(location),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  group('Utf8LengthLimitingFormatter', () {
    const formatter = Utf8LengthLimitingFormatter(NoteContent.maxTextBytes);
    const old = TextEditingValue(text: 'a');

    test('sınırı aşan değişiklik reddedilir', () {
      final next = TextEditingValue(text: 'ğ' * 33000);
      expect(formatter.formatEditUpdate(old, next), old);
    });

    test('sınır içindeki değişiklik geçer', () {
      final next = TextEditingValue(text: 'ğ' * 32000);
      expect(formatter.formatEditUpdate(old, next), next);
    });
  });

  testWidgets('ayrıntıda metin görünür, bütünü hassas panoya kopyalanır', (
    tester,
  ) async {
    await pumpApp(tester);
    await go(tester, AppRoutes.noteItem(loginIdHex(notes.items.first.id)));

    expect(find.byType(NoteDetailScreen), findsOneWidget);
    expect(find.text('ağ: Ev\nparola: kirmizi-kapi'), findsOneWidget);

    await tester.tap(find.text('Metni kopyala'));
    await tester.pump();

    expect(clipboard.copied, ['ağ: Ev\nparola: kirmizi-kapi']);
  });

  testWidgets('yeni not kaydedilir', (tester) async {
    await pumpApp(tester);
    await go(tester, AppRoutes.noteNew);
    expect(find.byType(NoteEditScreen), findsOneWidget);

    await tester.enterText(field('Ad'), 'Kapı');
    await tester.enterText(field('Metin'), 'kod 4821');
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(notes.items.last.content.name, 'Kapı');
    expect(notes.items.last.content.text, 'kod 4821');
    expect(find.byType(NoteEditScreen), findsNothing);
  });

  testWidgets('sınırı aşan metin kutuya girmez', (tester) async {
    await pumpApp(tester);
    await go(tester, AppRoutes.noteNew);

    await tester.enterText(field('Metin'), 'ğ' * 33000);
    await tester.pump();

    expect(tester.widget<TextField>(field('Metin')).controller!.text, isEmpty);
    // Sessizce reddedilmez: kullanıcı neden girmediğini görür.
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Not en çok 64 KiB olabilir. Fazlası eklenmedi.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('kaydedilmemiş değişiklikle çıkarken onay ister', (tester) async {
    await pumpApp(tester);
    await go(tester, AppRoutes.noteNew);

    await tester.enterText(field('Metin'), 'yarım');
    await tester.pump();
    await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
  });

  testWidgets('var olan not düzenlenir', (tester) async {
    await pumpApp(tester);
    await go(tester, AppRoutes.noteItemEdit(loginIdHex(notes.items.first.id)));

    await tester.enterText(field('Metin'), 'yeni metin');
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(notes.items.first.content.text, 'yeni metin');
    expect(notes.items.first.content.name, 'Ev Wi-Fi');
  });

  testWidgets('menüden çöp kutusuna taşınır', (tester) async {
    await pumpApp(tester);
    await go(tester, AppRoutes.noteItem(loginIdHex(notes.items.first.id)));

    await tester.tap(find.byTooltip('Diğer işlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çöp kutusuna taşı'));
    await tester.pumpAndSettle();

    expect(notes.items.first.content.isTrashed, isTrue);
  });
}
