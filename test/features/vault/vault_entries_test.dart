import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/application/vault_entries.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  var nextId = 0;
  Uint8List newId() => Uint8List(16)..[0] = nextId++;

  LoginEntry login(String name, {String? folder, DateTime? trashedAt}) =>
      LoginEntry(
        LoginItem(
          id: newId(),
          content: LoginContent(
            name: name,
            folder: folder,
            trashedAt: trashedAt,
          ),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

  CardEntry card(
    String name, {
    String number = '',
    String cardholder = '',
    String? folder,
    DateTime? trashedAt,
  }) => CardEntry(
    CardItem(
      id: newId(),
      content: CardContent(
        name: name,
        number: number,
        cardholder: cardholder,
        folder: folder,
        trashedAt: trashedAt,
      ),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );

  NoteEntry note(String name, {String text = '', String? folder}) => NoteEntry(
    NoteItem(
      id: newId(),
      content: NoteContent(name: name, text: text, folder: folder),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );

  List<IndexedEntry> index(List<VaultEntry> entries) =>
      entries.map(IndexedEntry.new).toList();

  List<String> names(List<VaultEntry> entries) =>
      entries.map((entry) => entry.name).toList();

  final entries = index([
    login('GitHub'),
    card('Maaş', number: '4111111111111111', cardholder: 'Ayşe Yılmaz'),
    card('Yedek', number: '5555555555554444'),
    note('Ev Wi-Fi', text: 'parola: kirmizi-kapi'),
  ]);

  test('tür süzgeci yalnızca o türü bırakır', () {
    expect(
      names(filterEntries(entries, const LoginFilter(kind: VaultKind.card))),
      ['Maaş', 'Yedek'],
    );
    expect(
      names(filterEntries(entries, const LoginFilter(kind: VaultKind.note))),
      ['Ev Wi-Fi'],
    );
  });

  test('kartta marka ve kart sahibi aranır', () {
    expect(names(filterEntries(entries, const LoginFilter(query: 'visa'))), [
      'Maaş',
    ]);
    expect(names(filterEntries(entries, const LoginFilter(query: 'ayse'))), [
      'Maaş',
    ]);
  });

  test('kart numarasında ve not metninde arama yapılmaz', () {
    expect(filterEntries(entries, const LoginFilter(query: '1111')), isEmpty);
    expect(
      filterEntries(entries, const LoginFilter(query: 'kirmizi')),
      isEmpty,
    );
  });

  test('klasör üç türde de Türkçe sadeleşmeyle bulunur', () {
    final foldered = index([
      login('A', folder: 'Şifre'),
      card('B', folder: 'Şifre'),
      note('C', folder: 'Şifre'),
      note('D'),
    ]);
    expect(names(filterEntries(foldered, const LoginFilter(query: 'sifre'))), [
      'A',
      'B',
      'C',
    ]);
  });

  test('çöptekiler süzgeçten çıkar', () {
    final mixed = index([
      card('Atılan', trashedAt: DateTime.utc(2026)),
      card('Kalan'),
    ]);
    expect(names(filterEntries(mixed, const LoginFilter())), ['Kalan']);
  });

  test('adsız kart listede görünen adıyla sıralanır', () {
    final zeytin = login('Zeytin');
    final nameless = card('', number: '4111111111111111');
    final banka = login('Banka');

    expect(sortEntries([zeytin, nameless, banka], LoginSort.name), [
      banka,
      nameless,
      zeytin,
    ]);
  });

  test('foldersOfEntries tekilleştirir ve sıralar', () {
    expect(
      foldersOfEntries([
        login('A', folder: 'Zeka'),
        card('B', folder: 'İş'),
        note('C', folder: 'İş'),
        card('D', folder: 'Gizli', trashedAt: DateTime.utc(2026)),
      ]),
      ['İş', 'Zeka'],
    );
  });

  test('copyWith türü temizleyebilir', () {
    const filter = LoginFilter(kind: VaultKind.card);
    expect(filter.copyWith(query: 'a').kind, VaultKind.card);
    expect(filter.copyWith(clearKind: true).kind, isNull);
  });

  group('vaultEntriesProvider', () {
    late ProviderContainer container;
    late SodiumSumo sodium;

    setUpAll(() async {
      sodium = await SodiumSumoInit.init();
    });

    ProviderContainer build({
      required FakeLoginRepository logins,
      required FakeRecordRepository<CardContent> cards,
      required FakeRecordRepository<NoteContent> notes,
    }) {
      final service = FakeVaultService(sodium);
      final created = ProviderContainer(
        overrides: [
          vaultServiceProvider.overrideWithValue(service),
          initialVaultStatusProvider.overrideWithValue(
            VaultOpen(service.newSession()),
          ),
          loginRepositoryFactoryProvider.overrideWithValue((_) => logins),
          cardRepositoryFactoryProvider.overrideWithValue((_) => cards),
          noteRepositoryFactoryProvider.overrideWithValue((_) => notes),
        ],
      );
      addTearDown(created.dispose);
      return created;
    }

    Future<VaultEntriesState> settled() async {
      for (var i = 0; i < 200; i++) {
        final state = container.read(vaultEntriesProvider);
        if (state is VaultEntriesLoaded) return state;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('Liste yüklenmedi');
    }

    test('üç tür yüklenince birlikte gelir', () async {
      container = build(
        logins: FakeLoginRepository(
          items: [FakeLoginRepository.item(const LoginContent(name: 'P'))],
          unreadableCount: 1,
        ),
        cards: FakeRecordRepository<CardContent>(
          items: [FakeRecordRepository.item(CardContent(name: 'K'), id: 1)],
          unreadableCount: 2,
        ),
        notes: FakeRecordRepository<NoteContent>(),
      )..listen(vaultEntriesProvider, (_, _) {});

      final state = await settled();

      expect(state, isA<VaultEntriesLoaded>());
      final loaded = state as VaultEntriesLoaded;
      expect(loaded.indexed.map((entry) => entry.entry.name), ['P', 'K']);
      expect(loaded.unreadableCount, 3);
      expect(loaded.activeKinds, {VaultKind.login, VaultKind.card});
    });

    test('yalnızca parola varken tek tür', () async {
      container = build(
        logins: FakeLoginRepository(
          items: [FakeLoginRepository.item(const LoginContent(name: 'P'))],
        ),
        cards: FakeRecordRepository<CardContent>(
          items: [
            FakeRecordRepository.item(
              CardContent(name: 'Çöpte', trashedAt: DateTime.utc(2026)),
              id: 1,
            ),
          ],
        ),
        notes: FakeRecordRepository<NoteContent>(),
      )..listen(vaultEntriesProvider, (_, _) {});

      final loaded = await settled() as VaultEntriesLoaded;

      expect(loaded.activeKinds, {VaultKind.login});
      expect(loaded.trashed.single.name, 'Çöpte');
    });

    test('kasa kilitliyken yükleniyor', () {
      final service = FakeVaultService(sodium);
      container = ProviderContainer(
        overrides: [
          vaultServiceProvider.overrideWithValue(service),
          initialVaultStatusProvider.overrideWithValue(const VaultNotSetUp()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(vaultEntriesProvider), isA<VaultEntriesLoading>());
    });
  });
}
