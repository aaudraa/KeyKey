import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:sodium/sodium_sumo.dart';

/// Kasanın yedeğini üretir.
///
/// Yedeğe yalnızca kayıtlar girer; parmak izi yuvası ve hatalı deneme sayacı
/// ayrı tablolardadır ve bu cihaza aittir.
class BackupService {
  new({required SodiumSumo sodium, required this._store})
    : _codec = BackupCodec(sodium);

  /// Önerilen dosya adı: `keykey-yedek-2026-11-07.keykey`.
  static String fileNameFor(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    final local = time.toLocal();
    return 'keykey-yedek-${local.year}-${two(local.month)}-'
        '${two(local.day)}.keykey';
  }

  /// Seçicide gösterilen tür. `.keykey` için kayıtlı bir MIME türü yok.
  static const mimeType = 'application/octet-stream';

  final VaultStore _store;
  final BackupCodec _codec;

  /// Açık kasanın yedeğini üretir. Kasa kilitlenirse `VaultLockedException`.
  Future<Uint8List> create(VaultSession session, DateTime now) async {
    final records = await _store.allRecords();
    return await _codec.encode(
      header: session.header,
      vaultKey: session.vaultKey,
      records: records,
      createdAt: now,
    );
  }
}

/// `main` doldurur, testler kendi servisini verir.
final backupServiceProvider = Provider<BackupService>(
  (ref) => throw UnimplementedError('Yedek servisi sağlanmadı.'),
);

/// Yedek zamanları için saat. Testler sabit bir saat verir.
final backupClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
