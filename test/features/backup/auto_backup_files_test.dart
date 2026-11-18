import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/application/auto_backup_files.dart';

void main() {
  const me = 'a1b2c3';
  const other = '0f9e8d';

  group('nameFor', () {
    test('önek, yerel tarih, saniyeli saat ve cihaz', () {
      expect(
        AutoBackupFiles.nameFor(
          DateTime(2026, 11, 18, 15, 30, 12),
          prefix: 'keykey-otomatik',
          device: me,
        ),
        'keykey-otomatik-2026-11-18-153012-a1b2c3.keykey',
      );
    });

    test('tek haneli alanlar sıfırla dolar', () {
      expect(
        AutoBackupFiles.nameFor(
          DateTime(2026, 1, 5, 9, 5, 1),
          prefix: 'keykey-auto',
          device: me,
        ),
        'keykey-auto-2026-01-05-090501-a1b2c3.keykey',
      );
    });
  });

  group('parse', () {
    test('ürettiği adı geri okur', () {
      final time = DateTime(2026, 11, 18, 15, 30, 12);
      for (final prefix in AutoBackupFiles.prefixes) {
        final parsed = AutoBackupFiles.parse(
          AutoBackupFiles.nameFor(time, prefix: prefix, device: me),
        );
        expect(parsed?.time, time);
        expect(parsed?.device, me);
      }
    });

    test('kalıba tam uymayan adlar otomatik yedek sayılmaz', () {
      for (final name in [
        'keykey-yedek-2026-11-18.keykey',
        'keykey-otomatik-2026-11-18-153012.keykey',
        'keykey-otomatik-2026-11-18-1530-a1b2c3.keykey',
        'keykey-otomatik-2026-13-01-000000-a1b2c3.keykey',
        'keykey-otomatik-2026-02-30-000000-a1b2c3.keykey',
        'keykey-otomatik-2026-11-18-240000-a1b2c3.keykey',
        'keykey-otomatik-2026-11-18-153012-A1B2C3.keykey',
        'keykey-otomatik-2026-11-18-153012-a1b2c.keykey',
        'keykey-otomatik-2026-11-18-153012-a1b2c3.keykey.bak',
        'keykey-otomatik-2026-11-18-153012-a1b2c3 (1).keykey',
        'KEYKEY-OTOMATIK-2026-11-18-153012-a1b2c3.keykey',
        'x-keykey-otomatik-2026-11-18-153012-a1b2c3.keykey',
        'notlar.txt',
        '',
      ]) {
        expect(AutoBackupFiles.parse(name), isNull, reason: name);
      }
    });
  });

  test('isDevice yalnızca 6 küçük onaltılık karakteri kabul eder', () {
    expect(AutoBackupFiles.isDevice(me), isTrue);
    for (final value in ['', 'a1b2c', 'a1b2c3d', 'A1B2C3', 'g1b2c3']) {
      expect(AutoBackupFiles.isDevice(value), isFalse, reason: value);
    }
  });

  group('toDelete', () {
    String auto(
      int day,
      int hour, {
      String prefix = 'keykey-otomatik',
      String device = me,
    }) => AutoBackupFiles.nameFor(
      DateTime(2026, 11, day, hour),
      prefix: prefix,
      device: device,
    );

    test('en yeni 5 dosya gün ne olursa olsun kalır', () {
      final names = [for (var hour = 9; hour <= 15; hour++) auto(18, hour)];
      expect(
        AutoBackupFiles.toDelete(names, device: me),
        unorderedEquals([auto(18, 9), auto(18, 10)]),
      );
    });

    test('en yeni 5 dosyanın dışında her günün en yenisi kalır', () {
      final names = [
        for (var hour = 10; hour <= 14; hour++) auto(18, hour),
        auto(17, 9),
        auto(17, 20),
        auto(16, 8),
      ];
      expect(AutoBackupFiles.toDelete(names, device: me), [auto(17, 9)]);
    });

    test('en yeni 14 gün kalır', () {
      final names = [for (var day = 1; day <= 16; day++) auto(day, 10)];
      expect(
        AutoBackupFiles.toDelete(names, device: me),
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
      expect(AutoBackupFiles.toDelete(names, device: me), [
        auto(1, 10, prefix: 'keykey-auto'),
      ]);
    });

    test('başka cihazın yedeklerine hiç dokunulmaz ve sayılmaz', () {
      final theirs = [
        for (var day = 1; day <= 16; day++) auto(day, 23, device: other),
        auto(18, 8, device: other),
      ];
      final mine = [for (var hour = 9; hour <= 15; hour++) auto(18, hour)];
      final deleted = AutoBackupFiles.toDelete([
        ...theirs,
        ...mine,
      ], device: me);
      expect(deleted, unorderedEquals([auto(18, 9), auto(18, 10)]));
    });

    test('kalıba uymayan dosyalara hiç dokunulmaz', () {
      final others = [
        'keykey-yedek-2026-11-01.keykey',
        'keykey-otomatik-2026-11-18-153012.keykey',
        'keykey-otomatik-2026-11-18-153012-a1b2c3 (1).keykey',
        'notlar.txt',
      ];
      final names = [
        ...others,
        for (var day = 1; day <= 16; day++) auto(day, 10),
        auto(18, 8),
      ];
      final deleted = AutoBackupFiles.toDelete(names, device: me);
      for (final name in others) {
        expect(deleted, isNot(contains(name)));
      }
      expect(deleted, unorderedEquals([auto(1, 10), auto(2, 10), auto(3, 10)]));
    });

    test('bu cihazın yarım kalmış ara dosyaları silinir', () {
      final part = '${auto(17, 9)}.part';
      final theirs = '${auto(17, 9, device: other)}.part';
      final deleted = AutoBackupFiles.toDelete([
        auto(18, 9),
        part,
        theirs,
        'notlar.part',
        '${auto(17, 9)}.part.bak',
      ], device: me);
      expect(deleted, [part]);
    });

    test('ara dosya adı son adın sonuna .part eklenmiş hali', () {
      expect(
        AutoBackupFiles.partName(auto(18, 9)),
        '${auto(18, 9)}${AutoBackupFiles.partSuffix}',
      );
      expect(AutoBackupFiles.partSuffix, '.part');
      expect(
        AutoBackupFiles.parse(AutoBackupFiles.partName(auto(18, 9))),
        isNull,
      );
    });

    test('boş klasörde silinecek bir şey yok', () {
      expect(AutoBackupFiles.toDelete(const [], device: me), isEmpty);
    });
  });
}
