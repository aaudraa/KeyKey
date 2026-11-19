import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/record_content.dart';

Uint8List _json(Map<String, Object?> value) => utf8.encode(jsonEncode(value));

Map<String, Object?> _valid() => {
  'version': 1,
  'name': 'Ev Wi-Fi',
  'text': 'ağ: Ev\nparola: gizli',
  'favorite': false,
  'folder': null,
  'trashedAt': null,
};

void main() {
  final full = NoteContent(
    name: 'Ev Wi-Fi',
    text: 'ağ: Ev\nparola: gizli',
    favorite: true,
    folder: 'Ev',
    trashedAt: DateTime.utc(2026, 11, 19),
  );

  test('gidiş-dönüş', () {
    final back = NoteContent.fromJsonBytes(full.toJsonBytes());
    expect(back.name, full.name);
    expect(back.text, full.text);
    expect(back.favorite, isTrue);
    expect(back.folder, 'Ev');
    expect(back.trashedAt, full.trashedAt);
  });

  test('alan adları tasarımdaki gibi', () {
    final decoded =
        jsonDecode(utf8.decode(full.toJsonBytes())) as Map<String, Object?>;
    expect(decoded.keys.toSet(), _valid().keys.toSet());
  });

  group('katı okuma', () {
    final broken = <String, Map<String, Object?> Function()>{
      'bilinmeyen sürüm': () => _valid()..['version'] = 2,
      'eksik alan': () => _valid()..remove('text'),
      'fazla alan': () => _valid()..['notes'] = '',
      'yanlış tür metin': () => _valid()..['text'] = 5,
    };
    for (final MapEntry(key: name, value: build) in broken.entries) {
      test(name, () {
        expect(
          () => NoteContent.fromJsonBytes(_json(build())),
          throwsA(isA<InvalidRecordContentException>()),
        );
      });
    }
  });

  group('64 KiB sınırı bayt üzerinden', () {
    test('32 000 "ğ" (64 000 bayt) kabul', () {
      final note = NoteContent(name: '', text: 'ğ' * 32000);
      expect(NoteContent.fromJsonBytes(note.toJsonBytes()).text.length, 32000);
    });

    test('33 000 "ğ" (66 000 bayt) kurucuda reddedilir', () {
      expect(
        () => NoteContent(name: '', text: 'ğ' * 33000),
        throwsArgumentError,
      );
    });

    test('33 000 "ğ" okurken reddedilir', () {
      expect(
        () =>
            NoteContent.fromJsonBytes(_json(_valid()..['text'] = 'ğ' * 33000)),
        throwsA(isA<InvalidRecordContentException>()),
      );
    });
  });

  test('withTrashedAt ve withFavorite', () {
    expect(full.withTrashedAt(null).isTrashed, isFalse);
    expect(full.withFavorite(favorite: false).favorite, isFalse);
    expect(full.withFavorite(favorite: false).text, full.text);
  });
}
