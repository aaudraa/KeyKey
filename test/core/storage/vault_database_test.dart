import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/storage/storage_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('keykey_db_');
    file = File('${directory.path}/keykey.db');
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  /// Şemayı `sqlite_master`'dan sıralı ve karşılaştırılabilir biçimde okur.
  Future<String> readSchema(VaultDatabase database) async {
    final rows = await database
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return rows.map((row) => '${row.read<String>('sql')};').join('\n');
  }

  group('şema', () {
    late String fixture;

    setUpAll(() {
      fixture = File('test/fixtures/storage/schema-v1.sql')
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .trim();
    });

    test('sürüm 1 sabit dosyayla aynı', () async {
      // Bu test kırılıyorsa şema değişmiştir: schemaVersion artırılmalı ve
      // eski dosyalar için göç yazılmalı. Sabit dosya sessizce değiştirilmez.
      final database = VaultDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      expect(database.schemaVersion, 1);
      expect(await readSchema(database), fixture);
    });

    test('sürüm 1 dosyası verisiyle birlikte açılıyor', () async {
      sqlite.sqlite3.open(file.path)
        ..execute(fixture)
        ..execute('PRAGMA user_version = 1')
        ..execute(
          "INSERT INTO vault_meta (id, header) VALUES (1, 'eski üst bilgi')",
        )
        ..close();

      final database = VaultDatabase.openFile(file);
      addTearDown(database.close);
      final row = await database.select(database.vaultMeta).getSingle();

      expect(row.header, 'eski üst bilgi');
    });

    test('daha yeni sürümün dosyası açılmıyor ve bozulmuyor', () async {
      sqlite.sqlite3.open(file.path)
        ..execute(fixture)
        ..execute('PRAGMA user_version = 2')
        ..execute("INSERT INTO vault_meta (id, header) VALUES (1, 'yeni')")
        ..close();

      expect(
        () => VaultDatabase.openFile(file),
        throwsA(
          isA<UnsupportedSchemaException>()
              .having((error) => error.from, 'from', 2)
              .having((error) => error.to, 'to', 1),
        ),
      );

      // Dosya bir şekilde kontrol olmadan açılırsa göç de reddetmeli.
      final direct = VaultDatabase(
        NativeDatabase(file, setup: configureConnection),
      );
      await expectLater(
        direct.select(direct.vaultMeta).get(),
        throwsA(isA<UnsupportedSchemaException>()),
      );
      await direct.close();

      final check = sqlite.sqlite3.open(file.path);
      addTearDown(check.close);
      expect(check.select('PRAGMA user_version').single.values.single, 2);
      expect(
        check.select('SELECT header FROM vault_meta').single.values.single,
        'yeni',
      );
    });
  });

  group('bağlantı ayarları', () {
    Future<Object?> pragma(VaultDatabase database, String name) async {
      final row = await database.customSelect('PRAGMA $name').getSingle();
      return row.data.values.single;
    }

    test('silinen veri üzerine yazılıyor ve günlük dosyası kalmıyor', () async {
      final database = VaultDatabase.openFile(file);
      addTearDown(database.close);

      expect(await pragma(database, 'secure_delete'), 1);
      expect(await pragma(database, 'journal_mode'), 'delete');
    });
  });

  group('kurallar veritabanında da zorlanıyor', () {
    late VaultDatabase database;

    setUp(() {
      database = VaultDatabase(NativeDatabase.memory());
    });

    tearDown(() => database.close());

    Matcher rejected() => throwsA(isA<Exception>());

    test('üst bilgi tablosunda ikinci satır olamıyor', () {
      expect(
        database
            .into(database.vaultMeta)
            .insert(VaultMetaCompanion.insert(id: const Value(2), header: 'x')),
        rejected(),
      );
    });

    test('yuva tablosunda ikinci satır olamıyor', () {
      expect(
        database
            .into(database.biometricSlot)
            .insert(
              BiometricSlotCompanion.insert(
                id: const Value(2),
                iv: Uint8List(12),
                cipherText: Uint8List(48),
              ),
            ),
        rejected(),
      );
    });

    test('yanlış uzunlukta yuva alanları reddediliyor', () async {
      await expectLater(
        database
            .into(database.biometricSlot)
            .insert(
              BiometricSlotCompanion.insert(
                id: const Value(1),
                iv: Uint8List(11),
                cipherText: Uint8List(48),
              ),
            ),
        rejected(),
      );
      await expectLater(
        database
            .into(database.biometricSlot)
            .insert(
              BiometricSlotCompanion.insert(
                id: const Value(1),
                iv: Uint8List(12),
                cipherText: Uint8List(47),
              ),
            ),
        rejected(),
      );
    });

    test('yanlış uzunlukta kayıt kimliği reddediliyor', () {
      expect(
        database
            .into(database.records)
            .insert(
              RecordsCompanion.insert(
                id: Uint8List(15),
                type: 'login',
                payload: Uint8List(1),
                createdAt: 0,
                updatedAt: 0,
              ),
            ),
        rejected(),
      );
    });
  });
}
