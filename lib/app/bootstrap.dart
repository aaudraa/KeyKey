import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/platform/pigeon_biometric_bridge.dart';
import 'package:keykey/core/storage/storage_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/generator/data/wordlists.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// Uygulamayı başlatır: libsodium'u yükler, kasa dosyasını açar ve başlangıç
/// durumunu belirler.
///
/// Dosya okunamıyorsa kullanıcıya hata ekranı gösterilir ve dosyaya dokunulmaz.
Future<List<Override>> bootstrap() async {
  final sodium = await SodiumSumoInit.init();
  final directory = await getApplicationSupportDirectory();

  final VaultDatabase database;
  try {
    database = VaultDatabase.openFile(File('${directory.path}/keykey.db'));
  } on UnsupportedSchemaException {
    return [
      initialVaultStatusProvider.overrideWithValue(const VaultUnavailable()),
    ];
  }

  final store = VaultStore(database);
  final service = VaultService(
    sodium: sodium,
    store: store,
    biometric: PigeonBiometricBridge(),
  );
  return [
    randomSourceProvider.overrideWithValue(SodiumRandomSource(sodium)),
    vaultServiceProvider.overrideWithValue(service),
    loginRepositoryFactoryProvider.overrideWithValue(
      (session) =>
          LoginRepository(store: store, session: session, sodium: sodium),
    ),
    initialVaultStatusProvider.overrideWithValue(await _loadStatus(service)),
  ];
}

Future<VaultStatus> _loadStatus(VaultService service) async {
  try {
    final header = await service.readHeader();
    return header == null ? const VaultNotSetUp() : VaultLocked(header);
  } on InvalidVaultHeaderException {
    return const VaultUnavailable();
  }
}
