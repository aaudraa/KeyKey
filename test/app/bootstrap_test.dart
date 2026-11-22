import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/bootstrap.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

/// Kasa dosyası okunamazsa uygulama açılış ekranında donmamalı, hata
/// ekranına düşmeli (VaultUnavailable).
void main() {
  late SodiumSumo sodium;
  late Directory directory;
  late File file;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    directory = Directory.systemTemp.createTempSync('keykey_bootstrap');
    file = File('${directory.path}/keykey.db');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('SQLite olmayan dosya hata ekranına düşüyor', () {
    file.writeAsBytesSync(List.filled(8192, 0x41));

    expect(openVaultDatabase(file), isNull);
  });

  test('sayfaları bozuk kasa hata ekranına düşüyor', () async {
    final created = VaultDatabase.openFile(file);
    expect(await VaultStore(created).readHeader(), isNull);
    await created.close();
    // İlk sayfa (sürüm) sağlam, tablolar bozuk.
    final bytes = file.readAsBytesSync();
    bytes.fillRange(4096, bytes.length, 0xFF);
    file.writeAsBytesSync(bytes);

    final database = openVaultDatabase(file);
    expect(database, isNotNull);
    final service = VaultService(sodium: sodium, store: VaultStore(database!));
    expect(await loadVaultStatus(service), isA<VaultUnavailable>());
    await database.close();
  });

  test('sağlam ama kurulmamış kasa kurulum ekranına gidiyor', () async {
    final database = openVaultDatabase(file)!;
    final service = VaultService(sodium: sodium, store: VaultStore(database));
    expect(await loadVaultStatus(service), isA<VaultNotSetUp>());
    await database.close();
  });
}
