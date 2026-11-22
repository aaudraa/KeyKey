import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_header.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_payload.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_xml.dart';

import '../../../../support/dart_kdbx_kdf.dart';
import '../../../../support/kdbx_fixtures.dart';

Future<KdbxDatabase> _database(String path) => kdbxFixtureDatabase(path);

String? _value(KdbxEntry entry, String key) => entry.strings[key]?.value;

void main() {
  test('test4: kayıtlar pykeepass ile aynı, geçmişten sonra da', () async {
    final db = await _database('pykeepass/test4.kdbx');
    // pykeepass 4.2.0'ın verdiği sırayla: grup yolu, başlık, kullanıcı adı,
    // parola, ek sayısı.
    final expected = <(List<String>, String?, String?, String?, int)>[
      ([], 'root_entry', 'foobar_user', 'passw0rd', 0),
      ([], 'foobar_entry', 'foobar', 'foobar', 1),
      ([], 'testing_new', 'lkj', 'poop', 0),
      ([], 'quote test -> " <-', null, null, 0),
      (
        [],
        'foobar_entry - Clone',
        '{REF:U@I:5060E2E029AA11E88AA80021CCB990C2}',
        '{REF:P@I:5060E2E029AA11E88AA80021CCB990C2}',
        0,
      ),
      (
        [],
        'foobar_entry - Clone of clone',
        '{REF:U@I:E402C98369ED4D18AD3D168117E306E6}',
        '{REF:P@I:E402C98369ED4D18AD3D168117E306E6}',
        0,
      ),
      (
        [],
        'foobar_entry - Clone with prefix and suffix',
        r'domain\{REF:U@I:5060E2E029AA11E88AA80021CCB990C2}2',
        'A{REF:P@I:5060E2E029AA11E88AA80021CCB990C2}BC',
        0,
      ),
      ([], null, 'blank_title', null, 0),
      ([], 'none_date', 'user', 'pass', 0),
      (['foobar_group'], 'group_entry', 'foobar_user', 'passw0rd', 0),
      (['foobar_group'], 'foobar_entry', 'foobar', 'foobar', 0),
      (['foobar_group', 'subgroup'], 'subentry', 'foobar', 'foobar', 0),
      (['foobar_group', 'subgroup'], 'subentry2', 'foobar', 'asdf', 0),
      (['foobar_group', 'subgroup'], 'foobar_entry', 'foobar', 'foobar', 0),
      (['Работа'], 'Тест', 'p', '1', 0),
    ];
    expect(db.entries, hasLength(expected.length));
    for (final (index, (path, title, user, password, files))
        in expected.indexed) {
      final entry = db.entries[index];
      expect(entry.groupPath, path, reason: '$index');
      // pykeepass boş değeri `None` gösteriyor.
      String? orNull(String? v) => v == null || v.isEmpty ? null : v;
      expect(orNull(_value(entry, 'Title')), title, reason: '$index');
      expect(orNull(_value(entry, 'UserName')), user, reason: '$index');
      expect(orNull(_value(entry, 'Password')), password, reason: '$index');
      expect(entry.attachments, files, reason: '$index');
    }
    expect(db.entries[1].uuid, '5060E2E029AA11E88AA80021CCB990C2');
    expect(_value(db.entries[1], 'multiline'), 'hello\nworld');
    expect(db.recycledEntries, 0);
  });

  test('korumalı ve korumasız alanlar ayrılır', () async {
    final db = await _database('keepassxc/ProtectedStrings.kdbx');
    final entry = db.entries.single;
    expect(entry.strings['TestProtected'], (value: 'ABC', protected: true));
    expect(entry.strings['TestUnprotected'], (value: 'DEF', protected: false));
    expect(_value(entry, 'Password'), 'ProtectedPassword');
    expect(_value(entry, 'UserName'), 'Protected User Name');
  });

  test('büyük-küçük harf farklı iki alan ayrı kalır', () async {
    final db = await _database('keepassxc/NewDatabase.kdbx');
    final entry = db.entries.first;
    expect(_value(entry, 'TestAttribute1'), 'b');
    expect(_value(entry, 'testattribute1'), 'a');
    expect(entry.attachments, 1);
  });

  test('çöp kutusu alınmaz ama sayılır', () async {
    final db = await _database('keepassxc/RecycleBinWithData.kdbx');
    expect(db.entries, hasLength(5));
    expect(db.recycledEntries, 6);
    expect(
      db.entries.map((e) => e.groupPath.first),
      isNot(contains('Recycle Bin')),
    );
  });

  test('KDBX 2: ekler sayılır, geçmiş kayıt sayılmaz', () async {
    final db = await _database('keepassxc/Format200.kdbx');
    final entry = db.entries.single;
    expect(_value(entry, 'Title'), 'Sample Entry');
    expect(_value(entry, 'UserName'), 'User Name');
    expect(entry.attachments, 2);
  });

  test('KDBX 4 ekleri ve çöp kutusu', () async {
    final db = await _database('keykey/keykey_ornek.kdbx');
    expect(db.recycledEntries, 1);
    final withFile = db.entries.firstWhere((e) => _value(e, 'Title') == 'Ekli');
    expect(withFile.attachments, 1);
    expect(db.entries.first.groupPath, ['E-posta', 'İş']);
  });

  test('başlık özeti tutmazsa bozuk', () async {
    final file = kdbxFixture('keepassxc/BrokenHeaderHash.kdbx');
    final header = KdbxHeader.parse(file);
    final transformed = await transformKey(
      header,
      kdbxFixtureComposite('keepassxc/Compressed.kdbx'),
      const DartKdbxKdf(),
    );
    final payload = decryptPayload(file, header, transformed);
    expect(
      () => parseKdbxXml(
        payload,
        headerBytes: header.bytes,
        majorVersion: header.majorVersion,
      ),
      throwsA(isA<KdbxCorrupt>()),
    );
  });
}
