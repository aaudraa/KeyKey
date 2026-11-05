import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

void main() {
  var nextId = 0;

  LoginItem item(
    String name, {
    String username = '',
    String password = '',
    List<String> urls = const [],
    String notes = '',
    bool favorite = false,
    String? folder,
    DateTime? trashedAt,
    DateTime? updatedAt,
  }) {
    final id = Uint8List(16)..[0] = nextId++;
    return LoginItem(
      id: id,
      content: LoginContent(
        name: name,
        username: username,
        password: password,
        urls: urls,
        notes: notes,
        favorite: favorite,
        folder: folder,
        trashedAt: trashedAt,
      ),
      createdAt: DateTime.utc(2026),
      updatedAt: updatedAt ?? DateTime.utc(2026),
    );
  }

  List<String> names(List<LoginItem> items) =>
      items.map((item) => item.content.name).toList();

  List<IndexedLogin> index(List<LoginItem> items) =>
      items.map(IndexedLogin.new).toList();

  group('Türkçe arama', () {
    test('harfler sadeleşiyor', () {
      expect(foldForSearch('İSTANBUL'), 'istanbul');
      expect(foldForSearch('ışık'), 'isik');
      expect(foldForSearch('ŞİFRE'), 'sifre');
      expect(foldForSearch('Çiğdem Öztürk'), 'cigdem ozturk');
    });

    test('her iki yazımla da bulunuyor', () {
      final logins = index([item('İş Bankası'), item('Ziraat')]);

      for (final query in ['iş', 'is', 'İŞ', 'IS', 'bankası', 'bankasi']) {
        expect(names(filterLogins(logins, LoginFilter(query: query))), [
          'İş Bankası',
        ], reason: query);
      }
    });
  });

  group('arama', () {
    final logins = index([
      item(
        'Posta',
        username: 'ali@example.com',
        password: 'gizliparola',
        urls: const ['https://mail.example.com'],
        notes: 'gizlinot',
        folder: 'Kişisel',
      ),
      item('Banka', username: 'veli'),
    ]);

    List<String> search(String query) =>
        names(filterLogins(logins, LoginFilter(query: query)));

    test('ad, kullanıcı adı, adres ve klasörde arıyor', () {
      expect(search('posta'), ['Posta']);
      expect(search('veli'), ['Banka']);
      expect(search('mail.example'), ['Posta']);
      expect(search('kişisel'), ['Posta']);
    });

    test('parolada ve notta aramıyor', () {
      expect(search('gizliparola'), isEmpty);
      expect(search('gizlinot'), isEmpty);
    });

    test('bütün sözcükler eşleşmeli', () {
      expect(search('posta ali'), ['Posta']);
      expect(search('posta veli'), isEmpty);
    });

    test('boş arama hepsini gösteriyor', () {
      expect(search(''), hasLength(2));
      expect(search('   '), hasLength(2));
    });
  });

  group('süzme', () {
    final logins = index([
      item('A', favorite: true, folder: 'İş'),
      item('B', folder: 'İş'),
      item('C', favorite: true),
      item('Silinen', trashedAt: DateTime.utc(2026), favorite: true),
    ]);

    test('çöp kutusu listede görünmüyor', () {
      expect(names(filterLogins(logins, const LoginFilter())), ['A', 'B', 'C']);
    });

    test('favoriler', () {
      expect(
        names(filterLogins(logins, const LoginFilter(favoritesOnly: true))),
        ['A', 'C'],
      );
    });

    test('klasör', () {
      expect(names(filterLogins(logins, const LoginFilter(folder: 'İş'))), [
        'A',
        'B',
      ]);
    });

    test('hepsi birlikte uygulanıyor', () {
      expect(
        names(
          filterLogins(
            logins,
            const LoginFilter(favoritesOnly: true, folder: 'İş', query: 'a'),
          ),
        ),
        ['A'],
      );
    });

    test('klasör listesi sıralı ve çöp kutusunu saymıyor', () {
      final items = [
        item('A', folder: 'Zeka'),
        item('B', folder: 'İş'),
        item('C', folder: 'İş'),
        item('D', folder: 'Silinen', trashedAt: DateTime.utc(2026)),
        item('E'),
      ];

      expect(foldersOf(items), ['İş', 'Zeka']);
    });
  });

  group('sıralama', () {
    test('ad sıralaması Türkçe harfleri doğru yere koyuyor', () {
      final sorted = sortLogins([
        item('Zeka'),
        item('Şifre'),
        item('İş'),
        item('ana'),
        item('Çanta'),
      ], LoginSort.name);

      expect(names(sorted), ['ana', 'Çanta', 'İş', 'Şifre', 'Zeka']);
    });

    test('son güncellenen önce', () {
      final sorted = sortLogins([
        item('Eski', updatedAt: DateTime.utc(2024)),
        item('Yeni', updatedAt: DateTime.utc(2026)),
        item('Orta', updatedAt: DateTime.utc(2025)),
      ], LoginSort.recentlyUpdated);

      expect(names(sorted), ['Yeni', 'Orta', 'Eski']);
    });
  });

  test('1000 kayıtta arama 16 ms altında', () {
    final logins = index([
      for (var i = 0; i < 1000; i++)
        item(
          'Kayıt $i',
          username: 'kullanici$i@example.com',
          urls: ['https://site$i.example.com/giris'],
          folder: 'Klasör ${i % 10}',
        ),
    ]);

    final stopwatch = Stopwatch()..start();
    final results = filterLogins(
      logins,
      const LoginFilter(query: 'kayıt 99 example'),
    );
    stopwatch.stop();

    expect(results, isNotEmpty);
    expect(stopwatch.elapsedMilliseconds, lessThan(16));
  });
}
