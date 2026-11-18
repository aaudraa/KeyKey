import 'dart:io';

import 'package:keykey/features/backup/application/auto_backup_files.dart';

/// Bu kurulumun otomatik yedek cihaz kimliği: kasanın dışında, uygulamanın
/// kendi klasöründe duran altı onaltılık karakter. Gizli değildir, yalnızca
/// aynı klasörü kullanan iki kurulumun yedeklerini ayırır. Yedekle taşınmaz;
/// uygulama yeniden kurulunca yenisi üretilir ve eski kimliğin dosyaları
/// budanmaz.
///
/// Dosya yoksa ya da içeriği geçersizse [random]'dan üç bayt alınıp yazılır.
Future<String> readOrCreateAutoBackupDevice(
  File file, {
  required List<int> Function(int length) random,
}) async {
  if (file.existsSync()) {
    final stored = (await file.readAsString()).trim();
    if (AutoBackupFiles.isDevice(stored)) return stored;
  }
  final id = [
    for (final byte in random(3)) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
  await file.writeAsString(id, flush: true);
  return id;
}
