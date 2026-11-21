import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/backup/data/export/bitwarden_csv_export.dart';
import 'package:keykey/features/backup/data/export/bitwarden_json_export.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';

/// Şifresiz dışa aktarmanın biçimi.
enum ExportFormat {
  /// Bitwarden CSV: parolalar, 2FA ve notlar; kartlar yazılmaz.
  csv,

  /// Bitwarden JSON: kartlar dahil her şey.
  json,
}

/// Şifresiz dışa aktarmanın kasa tarafı: kayıtları okur ve dosyanın
/// baytlarını üretir. Ekran depolara doğrudan erişmesin diye ayrı; böylece
/// en hassas yol ekran testi olmadan da sınanabilir. Kasa kilitlenirse
/// `VaultLockedException`.
final class PlaintextExporter {
  new(this._ref);

  final Ref _ref;

  /// Çöpte olmayan kart var mı; CSV kartları yazmadığı için biçim seçiminde
  /// söylenir.
  Future<bool> hasCards(VaultSession session) async {
    final cards = await _ref
        .read(cardRepositoryFactoryProvider)(session)
        .loadAll();
    return cards.items.any((item) => !item.content.isTrashed);
  }

  /// Dosyanın baytları, UTF-8. Kaydedildikten sonra sıfırlamak çağıranın işi.
  Future<Uint8List> build(VaultSession session, ExportFormat format) async {
    final logins = await _ref
        .read(loginRepositoryFactoryProvider)(session)
        .loadAll();
    final otps = await _ref
        .read(otpRepositoryFactoryProvider)(session)
        .loadAll();
    final notes = await _ref
        .read(noteRepositoryFactoryProvider)(session)
        .loadAll();
    final text = switch (format) {
      ExportFormat.csv => BitwardenCsvExport.build(
        logins: logins.items,
        otps: otps.items,
        notes: notes.items,
      ),
      ExportFormat.json => BitwardenJsonExport.build(
        logins: logins.items,
        otps: otps.items,
        cards:
            (await _ref.read(cardRepositoryFactoryProvider)(session).loadAll())
                .items,
        notes: notes.items,
      ),
    };
    return Uint8List.fromList(utf8.encode(text));
  }
}

final plaintextExporterProvider = Provider<PlaintextExporter>(
  PlaintextExporter.new,
);
