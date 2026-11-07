import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/csv_reader.dart';

void main() {
  test('basit satırlar', () {
    expect(CsvReader.read('a,b,c\n1,2,3\n'), [
      ['a', 'b', 'c'],
      ['1', '2', '3'],
    ]);
  });

  test('son satırda satır sonu olmayabilir, CRLF ve CR çalışıyor', () {
    expect(CsvReader.read('a,b\r\n1,2'), [
      ['a', 'b'],
      ['1', '2'],
    ]);
    expect(CsvReader.read('a\rb'), [
      ['a'],
      ['b'],
    ]);
  });

  test('tırnak içinde virgül, satır sonu ve kaçış', () {
    expect(CsvReader.read('"a,b","satır\nalt","o ""tırnak"" dedi"\n'), [
      ['a,b', 'satır\nalt', 'o "tırnak" dedi'],
    ]);
  });

  test('boş alanlar korunuyor', () {
    expect(CsvReader.read(',,\n"",x,\n'), [
      ['', '', ''],
      ['', 'x', ''],
    ]);
  });

  test('BOM atlanıyor, boş satırlar atlanıyor', () {
    expect(CsvReader.read('﻿ad,parola\n\n\nx,y\n'), [
      ['ad', 'parola'],
      ['x', 'y'],
    ]);
  });

  test('Türkçe ve emoji karakterler bozulmuyor', () {
    expect(CsvReader.read('ığüşöç,🔑\n'), [
      ['ığüşöç', '🔑'],
    ]);
  });

  test('bozuk tırnaklar reddediliyor', () {
    for (final text in ['"açık', 'a"b,c', '"a"b,c', '"a" ,b']) {
      expect(
        () => CsvReader.read(text),
        throwsA(isA<CsvFormatException>()),
        reason: text,
      );
    }
  });

  test('çok fazla alan reddediliyor', () {
    expect(
      () => CsvReader.read(List.filled(CsvReader.maxFields + 1, 'x').join(',')),
      throwsA(isA<CsvFormatException>()),
    );
  });

  test('rastgele girdiler yalnızca kendi hatasını veriyor', () {
    final random = Random(11);
    const alphabet = 'ab,"\r\n ığ';
    for (var round = 0; round < 2000; round++) {
      final text = String.fromCharCodes([
        for (var i = 0; i < random.nextInt(40); i++)
          alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ]);
      try {
        CsvReader.read(text);
      } on CsvFormatException {
        // Beklenen.
      }
    }
  });
}
