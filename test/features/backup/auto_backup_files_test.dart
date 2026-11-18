import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/application/auto_backup_files.dart';

void main() {
  group('nameFor', () {
    test('önek, yerel tarih ve saniyeli saat', () {
      expect(
        AutoBackupFiles.nameFor(
          DateTime(2026, 11, 18, 15, 30, 12),
          prefix: 'keykey-otomatik',
        ),
        'keykey-otomatik-2026-11-18-153012.keykey',
      );
    });

    test('tek haneli alanlar sıfırla dolar', () {
      expect(
        AutoBackupFiles.nameFor(
          DateTime(2026, 1, 5, 9, 5, 1),
          prefix: 'keykey-auto',
        ),
        'keykey-auto-2026-01-05-090501.keykey',
      );
    });
  });

  group('parse', () {
    test('ürettiği adı geri okur', () {
      final time = DateTime(2026, 11, 18, 15, 30, 12);
      for (final prefix in AutoBackupFiles.prefixes) {
        expect(
          AutoBackupFiles.parse(AutoBackupFiles.nameFor(time, prefix: prefix)),
          time,
        );
      }
    });

    test('kalıba tam uymayan adlar otomatik yedek sayılmaz', () {
      for (final name in [
        'keykey-yedek-2026-11-18.keykey',
        'keykey-otomatik-2026-11-18-1530.keykey',
        'keykey-otomatik-2026-13-01-000000.keykey',
        'keykey-otomatik-2026-02-30-000000.keykey',
        'keykey-otomatik-2026-11-18-240000.keykey',
        'keykey-otomatik-2026-11-18-153012.keykey.bak',
        'keykey-otomatik-2026-11-18-153012 (1).keykey',
        'KEYKEY-OTOMATIK-2026-11-18-153012.keykey',
        'x-keykey-otomatik-2026-11-18-153012.keykey',
        'notlar.txt',
        '',
      ]) {
        expect(AutoBackupFiles.parse(name), isNull, reason: name);
      }
    });
  });

  group('toDelete', () {
    String auto(int day, int hour, {String prefix = 'keykey-otomatik'}) =>
        AutoBackupFiles.nameFor(DateTime(2026, 11, day, hour), prefix: prefix);

    test('aynı günün en yenisi kalır', () {
      final names = [auto(18, 9), auto(18, 15), auto(18, 12)];
      expect(
        AutoBackupFiles.toDelete(names),
        unorderedEquals([auto(18, 9), auto(18, 12)]),
      );
    });

    test('en yeni 14 gün kalır', () {
      final names = [for (var day = 1; day <= 16; day++) auto(day, 10)];
      expect(
        AutoBackupFiles.toDelete(names),
        unorderedEquals([auto(1, 10), auto(2, 10)]),
      );
    });

    test('iki önek birlikte sayılır', () {
      final names = [
        auto(18, 9, prefix: 'keykey-auto'),
        auto(18, 15),
        for (var day = 1; day <= 14; day++)
          auto(day, 10, prefix: 'keykey-auto'),
      ];
      expect(
        AutoBackupFiles.toDelete(names),
        unorderedEquals([
          auto(18, 9, prefix: 'keykey-auto'),
          auto(1, 10, prefix: 'keykey-auto'),
        ]),
      );
    });

    test('kalıba uymayan dosyalara hiç dokunulmaz', () {
      final others = [
        'keykey-yedek-2026-11-01.keykey',
        'keykey-otomatik-2026-11-18-1530.keykey',
        'keykey-otomatik-2026-11-18-153012 (1).keykey',
        'notlar.txt',
      ];
      final names = [
        ...others,
        for (var day = 1; day <= 16; day++) auto(day, 10),
        auto(18, 8),
      ];
      final deleted = AutoBackupFiles.toDelete(names);
      for (final name in others) {
        expect(deleted, isNot(contains(name)));
      }
      expect(deleted, unorderedEquals([auto(1, 10), auto(2, 10), auto(3, 10)]));
    });

    test('boş klasörde silinecek bir şey yok', () {
      expect(AutoBackupFiles.toDelete(const []), isEmpty);
    });
  });
}
