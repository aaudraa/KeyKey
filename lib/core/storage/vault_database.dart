import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:keykey/core/storage/storage_exceptions.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

part 'vault_database.g.dart';

/// Kasa üst bilgisinin durduğu tek satırlık tablo.
///
/// Bu satırın varlığı, kasanın kurulu olduğunu gösteren tek işarettir.
@DataClassName('VaultMetaRow')
class VaultMeta extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();
  TextColumn get header => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Şifreli kayıtlar. Başlık, kullanıcı adı ve URL `blob` alanının içindedir.
@DataClassName('RecordRow')
class Records extends Table {
  BlobColumn get id =>
      blob().customConstraint('NOT NULL CHECK (length(id) = 16)')();
  TextColumn get type => text()();
  BlobColumn get payload => blob().named('blob')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  bool get withoutRowId => true;
}

/// Parmak izi yuvası. Yalnızca özellik açıksa satır vardır, yedeğe girmez.
@DataClassName('BiometricSlotRow')
class BiometricSlot extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();
  BlobColumn get iv =>
      blob().customConstraint('NOT NULL CHECK (length(iv) = 12)')();
  BlobColumn get cipherText =>
      blob().customConstraint('NOT NULL CHECK (length(cipher_text) = 48)')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Hatalı parola denemeleri. Uygulama yeniden başlayınca sıfırlanmaz.
@DataClassName('UnlockStateRow')
class UnlockState extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();
  IntColumn get failedAttempts => integer()();
  IntColumn get lastFailedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Eski sarmalama satırlarının dosyanın boş alanında kalmamasını sağlar.
///
/// Ayrıntılar güvenlik tasarımı belgesinin Depolama bölümünde.
void configureConnection(sqlite.Database database) {
  database
    ..execute('PRAGMA journal_mode = DELETE')
    ..execute('PRAGMA secure_delete = ON');
}

@DriftDatabase(tables: [VaultMeta, Records, BiometricSlot, UnlockState])
final class VaultDatabase extends _$VaultDatabase {
  new(super.e);

  /// Verilen dosyayı arka planda çalışan bir bağlantıyla açar.
  ///
  /// Dosya daha yeni bir şemadaysa [UnsupportedSchemaException] fırlatır. Bu
  /// kontrol bağlantıdan önce yapılır, çünkü arka plandaki bağlantının hataları
  /// türünü kaybederek gelir.
  factory openFile(File file) {
    _rejectNewerSchema(file);
    return VaultDatabase(
      NativeDatabase.createInBackground(file, setup: configureConnection),
    );
  }

  /// Üst bilgi biçiminin sürümünden bağımsızdır.
  static const currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  static void _rejectNewerSchema(File file) {
    if (!file.existsSync()) return;
    final database = sqlite.sqlite3.open(
      file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      final found = database.userVersion;
      if (found > currentSchemaVersion) {
        throw UnsupportedSchemaException(from: found, to: currentSchemaVersion);
      }
    } finally {
      database.close();
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    // Henüz göç yok. Daha yeni bir sürümün yazdığı dosya da buraya düşer ve
    // açılmaz, çünkü eski kod bilmediği bir şemayı bozabilir.
    onUpgrade: (migrator, from, to) async {
      throw UnsupportedSchemaException(from: from, to: to);
    },
  );
}
