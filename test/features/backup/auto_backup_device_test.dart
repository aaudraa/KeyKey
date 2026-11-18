import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/application/auto_backup_files.dart';
import 'package:keykey/features/backup/data/auto_backup_device.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('kk_cihaz_');
    file = File('${directory.path}/auto_backup_device');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test(
    'dosya yoksa rastgele kimlik üretilip yazılıyor, sonra aynısı okunuyor',
    () async {
      var calls = 0;
      List<int> random(int length) {
        calls++;
        return List.filled(length, 0xab);
      }

      final first = await readOrCreateAutoBackupDevice(file, random: random);
      expect(first, 'ababab');
      expect(AutoBackupFiles.isDevice(first), isTrue);
      expect(file.readAsStringSync(), 'ababab');

      final second = await readOrCreateAutoBackupDevice(file, random: random);
      expect(second, first);
      expect(calls, 1);
    },
  );

  test('bozuk içerik yeni kimlikle değiştiriliyor', () async {
    file.writeAsStringSync('XYZ\n');
    final id = await readOrCreateAutoBackupDevice(
      file,
      random: (length) => List.filled(length, 0x01),
    );
    expect(id, '010101');
    expect(file.readAsStringSync(), '010101');
  });
}
