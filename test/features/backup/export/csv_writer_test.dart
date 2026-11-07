import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/export/csv_writer.dart';
import 'package:keykey/features/backup/data/import/csv_reader.dart';

void main() {
  test('gereken alanlar tırnağa alınıyor', () {
    expect(
      CsvWriter.write([
        ['a', 'b,c', 'o "dedi"', 'iki\nsatır', ' boşluk', ''],
      ]),
      'a,"b,c","o ""dedi""","iki\nsatır"," boşluk",\r\n',
    );
  });

  test('formül gibi görünen değer olduğu gibi kalıyor', () {
    expect(
      CsvWriter.write([
        ['=1+2', '@x'],
      ]),
      '=1+2,@x\r\n',
    );
  });

  test('rastgele değerler okuyucudan aynen geri geliyor', () {
    final random = Random(7);
    const alphabet = 'ab ,"\r\nığ🔑=';
    final runes = alphabet.runes.toList();
    for (var round = 0; round < 500; round++) {
      final rows = [
        for (var r = 0; r < 1 + random.nextInt(4); r++)
          [
            // İlk alan boş olmasın: tamamen boş satırları okuyucu atlıyor.
            'x',
            for (var f = 0; f < random.nextInt(5); f++)
              String.fromCharCodes([
                for (var i = 0; i < random.nextInt(8); i++)
                  runes[random.nextInt(runes.length)],
              ]),
          ],
      ];
      expect(CsvReader.read(CsvWriter.write(rows)), rows);
    }
  });
}
