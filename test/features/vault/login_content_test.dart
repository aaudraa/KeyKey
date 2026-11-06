import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/vault/data/login_content.dart';

void main() {
  final full = LoginContent(
    name: 'Örnek Şifre',
    username: 'kullanici@example.com',
    password: 'gizli-değer',
    urls: const ['https://example.com', 'https://giris.example.com'],
    notes: 'Bir not',
    customFields: const [
      LoginCustomField(name: 'PIN', value: '1234', hidden: true),
      LoginCustomField(name: 'Şehir', value: 'İzmir'),
    ],
    favorite: true,
    folder: 'İş',
    trashedAt: DateTime.utc(2026, 11, 5, 12),
    passwordHistory: [
      PasswordHistoryEntry(
        password: 'eski-değer',
        changedAt: DateTime.utc(2026, 11, 2),
      ),
    ],
  );

  Map<String, Object?> json(LoginContent content) =>
      jsonDecode(utf8.decode(content.toJsonBytes())) as Map<String, Object?>;

  Uint8List bytes(Map<String, Object?> map) =>
      Uint8List.fromList(utf8.encode(jsonEncode(map)));

  void expectSame(LoginContent actual, LoginContent expected) {
    expect(actual.name, expected.name);
    expect(actual.username, expected.username);
    expect(actual.password, expected.password);
    expect(actual.urls, expected.urls);
    expect(actual.notes, expected.notes);
    expect(actual.customFields, expected.customFields);
    expect(actual.favorite, expected.favorite);
    expect(actual.folder, expected.folder);
    expect(actual.trashedAt, expected.trashedAt);
    expect(actual.passwordHistory, expected.passwordHistory);
  }

  group('biçim', () {
    test('yazılan aynen okunuyor', () {
      expectSame(LoginContent.fromJsonBytes(full.toJsonBytes()), full);
    });

    test('boş içerik aynen okunuyor', () {
      const empty = LoginContent(name: '');
      expectSame(LoginContent.fromJsonBytes(empty.toJsonBytes()), empty);
    });

    test('sabit örnek dosya açılıyor', () {
      // Bu dosya değişmez: eski kasalar her sürümde açılmalı.
      final fixture = File('test/fixtures/vault/login-v1.json')
          .readAsBytesSync();

      final content = LoginContent.fromJsonBytes(fixture);

      expect(content.name, 'Örnek');
      expect(content.username, 'kullanici@example.com');
      expect(content.password, 'deneme-degeri');
      expect(content.urls, ['https://example.com']);
      expect(content.notes, 'Not');
      expect(content.customFields, [
        const LoginCustomField(name: 'PIN', value: 'deneme', hidden: true),
      ]);
      expect(content.favorite, isTrue);
      expect(content.folder, 'İş');
      expect(content.trashedAt, isNull);
      expect(content.passwordHistory, [
        PasswordHistoryEntry(
          password: 'eski-deger',
          changedAt: DateTime.fromMillisecondsSinceEpoch(
            1730000000000,
            isUtc: true,
          ),
        ),
      ]);
    });
  });

  group('katı okuma', () {
    Matcher rejected() => throwsA(isA<InvalidLoginContentException>());

    test('JSON olmayan içerik', () {
      expect(
        () => LoginContent.fromJsonBytes(Uint8List.fromList([1, 2, 3])),
        rejected(),
      );
    });

    test('bilinmeyen sürüm', () {
      final map = json(full)..['version'] = 2;
      expect(() => LoginContent.fromJsonBytes(bytes(map)), rejected());
    });

    test('eksik alanlar', () {
      for (final key in json(full).keys) {
        final map = json(full)..remove(key);
        expect(
          () => LoginContent.fromJsonBytes(bytes(map)),
          rejected(),
          reason: key,
        );
      }
    });

    test('fazla alan', () {
      final map = json(full)..['fazla'] = 1;
      expect(() => LoginContent.fromJsonBytes(bytes(map)), rejected());
    });

    test('yanlış türler', () {
      for (final key in json(full).keys) {
        if (key == 'version') continue;
        final map = json(full)..[key] = {'yanlis': true};
        expect(
          () => LoginContent.fromJsonBytes(bytes(map)),
          rejected(),
          reason: key,
        );
      }
    });

    test('DateTime aralığı dışındaki zaman', () {
      // RangeError değil, içerik hatası olmalı; yoksa liste düşerdi.
      for (final value in [8640000000000001, -8640000000000001]) {
        final map = json(full)..['trashedAt'] = value;
        expect(() => LoginContent.fromJsonBytes(bytes(map)), rejected());
      }
    });

    test('hata mesajında değer yok', () {
      final map = json(full)..['password'] = 12345;
      try {
        LoginContent.fromJsonBytes(bytes(map));
        fail('Hata bekleniyordu');
      } on InvalidLoginContentException catch (error) {
        expect(error.toString(), isNot(contains('12345')));
      }
    });
  });

  group('parola geçmişi', () {
    final now = DateTime.utc(2026, 11, 5);
    const original = LoginContent(name: 'A', password: 'eski');

    test('parola değişince eskisi başa ekleniyor', () {
      final edited = original.applyEdit(
        original.copyWith(password: 'yeni'),
        now,
      );

      expect(edited.password, 'yeni');
      expect(edited.passwordHistory, [
        PasswordHistoryEntry(password: 'eski', changedAt: now),
      ]);
    });

    test('parola aynıysa geçmiş değişmiyor', () {
      final edited = original.applyEdit(original.copyWith(name: 'B'), now);

      expect(edited.name, 'B');
      expect(edited.passwordHistory, isEmpty);
    });

    test('boş parola geçmişe yazılmıyor', () {
      const empty = LoginContent(name: 'A');

      final edited = empty.applyEdit(empty.copyWith(password: 'yeni'), now);

      expect(edited.passwordHistory, isEmpty);
    });

    test('en fazla 10 eski parola tutuluyor', () {
      var content = original;
      for (var i = 0; i < 15; i++) {
        content = content.applyEdit(content.copyWith(password: 'p$i'), now);
      }

      expect(content.passwordHistory, hasLength(10));
      expect(content.passwordHistory.first.password, 'p13');
    });

    test('düzenleme formu geçmişi değiştiremiyor', () {
      final withHistory = original.applyEdit(
        original.copyWith(password: 'yeni'),
        now,
      );

      final edited = withHistory.applyEdit(
        withHistory.copyWith(passwordHistory: const []),
        now,
      );

      expect(edited.passwordHistory, withHistory.passwordHistory);
    });
  });

  group('değiştirme', () {
    test('verilmeyen klasör ve çöp bilgisi korunuyor', () {
      final copy = full.copyWith(name: 'Yeni');

      expect(copy.folder, 'İş');
      expect(copy.trashedAt, full.trashedAt);
    });

    test('null verilince temizleniyor', () {
      final copy = full.copyWith(folder: null, trashedAt: null);

      expect(copy.folder, isNull);
      expect(copy.isTrashed, isFalse);
    });
  });
}
