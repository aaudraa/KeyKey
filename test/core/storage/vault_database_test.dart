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

  /// Sürüm 2 şemasının sabit dosyası.
  String readFixtureSchema() =>
      File('test/fixtures/storage/schema-v2.sql')
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .trim();

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
    late String fixtureV1;

    String readFixture(String name) =>
        File('test/fixtures/storage/$name')
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .trim();

    setUpAll(() {
      fixture = readFixture('schema-v2.sql');
      fixtureV1 = readFixture('schema-v1.sql');
    });

    /// Tablonun sütun adları, sırasıyla.
    Future<List<String>> columns(VaultDatabase database, String table) async {
      final rows = await database
          .customSelect('PRAGMA table_info($table)')
          .get();
      return rows.map((row) => row.read<String>('name')).toList();
    }

    test('sürüm 2 sabit dosyayla aynı', () async {
      // Bu test kırılıyorsa şema değişmiştir: schemaVersion artırılmalı ve
      // eski dosyalar için göç yazılmalı. Sabit dosya sessizce değiştirilmez.
      final database = VaultDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      expect(database.schemaVersion, 2);
      expect(await readSchema(database), fixture);
    });

    test('sürüm 1 dosyası verisiyle birlikte sürüm 2ye geçiyor', () async {
      sqlite.sqlite3.open(file.path)
        ..execute(fixtureV1)
        ..execute('PRAGMA user_version = 1')
        ..execute(
          "INSERT INTO vault_meta (id, header) VALUES (1, 'eski üst bilgi')",
        )
        ..execute(
          'INSERT INTO records (id, type, blob, created_at, updated_at) '
          "VALUES (zeroblob(16), 'login', x'01', 1, 2)",
        )
        ..close();

      final database = VaultDatabase.openFile(file);
      addTearDown(database.close);
      final row = await database.select(database.vaultMeta).getSingle();

      expect(row.header, 'eski üst bilgi');
      expect(row.passwordChangedAt, isNull);
      expect(row.recoveryChangedAt, isNull);
      expect(await database.select(database.records).get(), hasLength(1));
      expect(await database.select(database.tombstones).get(), isEmpty);
      expect(await columns(database, 'vault_meta'), [
        'id',
        'header',
        'password_changed_at',
        'recovery_changed_at',
      ]);
      expect(await columns(database, 'tombstones'), ['id', 'deleted_at']);

      final check = sqlite.sqlite3.open(file.path);
      addTearDown(check.close);
      expect(check.select('PRAGMA user_version').single.values.single, 2);
    });

    test('daha yeni sürümün dosyası açılmıyor ve bozulmuyor', () async {
      sqlite.sqlite3.open(file.path)
        ..execute(fixture)
        ..execute('PRAGMA user_version = 3')
        ..execute("INSERT INTO vault_meta (id, header) VALUES (1, 'yeni')")
        ..close();

      expect(
        () => VaultDatabase.openFile(file),
        throwsA(
          isA<UnsupportedSchemaException>()
              .having((error) => error.from, 'from', 3)
              .having((error) => error.to, 'to', 2),
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
      expect(check.select('PRAGMA user_version').single.values.single, 3);
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

    test(
      'yazma ortasında ölen sürecin günlüğü açılışta geri alınıyor',
      () async {
        // Çökmüş bir yazmanın izini üretir: işlem sürerken veritabanı dosyası
        // ve sıcak günlük başka bir yere kopyalanır, işlem hiç bitmemiş olur.
        final source = File('${directory.path}/kaynak.db');
        sqlite.sqlite3.open(source.path)
          ..execute(readFixtureSchema())
          ..execute('PRAGMA user_version = 2')
          ..execute("INSERT INTO vault_meta (id, header) VALUES (1, 'eski')")
          ..close();
        final writer = sqlite.sqlite3.open(source.path)
          ..execute('PRAGMA journal_mode = DELETE')
          ..execute('PRAGMA cache_size = 2')
          ..execute('BEGIN IMMEDIATE')
          ..execute("UPDATE vault_meta SET header = 'yarım' WHERE id = 1");
        for (var i = 0; i < 200; i++) {
          writer.execute(
            'INSERT INTO records (id, type, blob, created_at, updated_at) '
            "VALUES (randomblob(16), 'login', randomblob(1000), 1, 2)",
          );
        }
        final journal = File('${source.path}-journal');
        expect(journal.existsSync(), isTrue);
        source.copySync(file.path);
        journal.copySync('${file.path}-journal');
        writer
          ..execute('ROLLBACK')
          ..close();

        final database = VaultDatabase.openFile(file);
        addTearDown(database.close);
        final row = await database.select(database.vaultMeta).getSingle();

        expect(row.header, 'eski');
        expect(await database.select(database.records).get(), isEmpty);
        expect(File('${file.path}-journal').existsSync(), isFalse);
      },
    );
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
