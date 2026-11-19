import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/network/pwned_passwords_client.dart';
import 'package:keykey/features/vault/application/breach_check.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

import '../../support/fake_range_source.dart';
import '../../support/fake_vault_service.dart';

LoginItem _login(
  int id,
  String password, {
  String? name,
  bool trashed = false,
}) => FakeLoginRepository.item(
  LoginContent(
    name: name ?? 'Kayıt $id',
    password: password,
    trashedAt: trashed ? DateTime.utc(2026, 11) : null,
  ),
  id: id,
);

String _suffix(String password) => pwnedHash(password).substring(5);

String _prefix(String password) => pwnedHash(password).substring(0, 5);

void main() {
  test('özet değerleri', () {
    expect(pwnedHash('password'), '5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8');
    expect(pwnedHash('abc'), 'A9993E364706816ABA3E25717850C26C9CD0D89D');
    expect(pwnedHash('şifre'), 'F03EA60F6F5B83B64103EBFF11C5249ACAE2E687');
  });

  test('yanıt okuma: dolgu atılır', () {
    expect(
      parsePwnedRange(
        '1E4C9B93F3F0682250B6CF8331B7EE68FD8:9659365\r\n'
        '0018A45C4D1DEF81644B54AB7F969B88D65:0\r\n\r\n',
      ),
      {'1E4C9B93F3F0682250B6CF8331B7EE68FD8': 9659365},
    );
    expect(parsePwnedRange(''), isEmpty);
  });

  test('yanıt okuma: geçersiz satır', () {
    for (final body in [
      '1e4c9b93f3f0682250b6cf8331b7ee68fd8:1',
      'XYZ:1',
      '<html><body>Giriş yap</body></html>',
      '1E4C9B93F3F0682250B6CF8331B7EE68FD8:abc',
      '1E4C9B93F3F0682250B6CF8331B7EE68FD8',
      '1E4C9B93F3F0682250B6CF8331B7EE68FD8:-1',
    ]) {
      expect(() => parsePwnedRange(body), throwsFormatException, reason: body);
    }
  });

  test('sızan parolanın sayısı', () async {
    final source = FakeRangeSource(
      (prefix) => prefix == '5BAA6'
          ? '${_suffix('password')}:10\r\n$pwnedPadding:0\r\n'
          : '$pwnedPadding:0\r\n',
    );
    const strong = 'Vq7#kL2m!xR9pZ4wTe';

    final result = await BreachChecker(source)
        .check([_login(1, 'password'), _login(2, strong)]);

    expect(result.countFor('password'), 10);
    expect(result.countFor(strong), 0);
    expect(result.countFor('hiç sorulmadı'), isNull);
  });

  test('aynı parola bir kez sorulur', () async {
    final source = FakeRangeSource();

    await BreachChecker(source).check([
      _login(1, 'password'),
      _login(2, 'password'),
      _login(3, 'password'),
    ]);

    expect(source.calls, ['5BAA6']);
  });

  test('çöp ve boş parola atlanır', () async {
    final source = FakeRangeSource();

    final result = await BreachChecker(source)
        .check([_login(1, 'password', trashed: true), _login(2, '')]);

    expect(source.calls, isEmpty);
    expect(result.countFor('password'), isNull);
  });

  test(
    'yüzlerce parola: en çok 4 istek aynı anda, ilerleme sona varır',
    () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final source = FakeRangeSource((prefix) async {
        inFlight++;
        maxInFlight = max(maxInFlight, inFlight);
        await Future<void>.delayed(const Duration(milliseconds: 1));
        inFlight--;
        return '$pwnedPadding:0\r\n';
      });
      final items = [
        for (var i = 0; i < 300; i++) _login(i % 250, 'parola-$i'),
      ];
      final prefixes = {
        for (final item in items) _prefix(item.content.password),
      };
      final progress = <(int, int)>[];

      await BreachChecker(
        source,
      ).check(items, onProgress: (done, total) => progress.add((done, total)));

      expect(maxInFlight, lessThanOrEqualTo(4));
      expect(maxInFlight, greaterThan(1));
      expect(source.calls.toSet(), prefixes);
      expect(source.calls, hasLength(prefixes.length));
      expect(progress.first, (0, prefixes.length));
      expect(progress.last, (prefixes.length, prefixes.length));
    },
  );

  test('önekler kayıt sırasıyla gitmez', () async {
    final source = FakeRangeSource();
    final items = [for (var i = 0; i < 40; i++) _login(i, 'parola-$i')];
    final inOrder = <String>{
      for (final item in items) _prefix(item.content.password),
    }.toList();

    await BreachChecker(source, concurrency: 1, random: Random(7)).check(items);

    expect(source.calls.toSet(), inOrder.toSet());
    expect(source.calls, isNot(inOrder));
  });

  test('bir kez yeniden dener', () async {
    var attempts = 0;
    final source = FakeRangeSource((prefix) {
      attempts++;
      if (attempts == 1) throw const PwnedPasswordsException('bağlantı');
      return '${_suffix('password')}:3\r\n';
    });

    final result = await BreachChecker(source).check([_login(1, 'password')]);

    expect(attempts, 2);
    expect(result.countFor('password'), 3);
  });

  test('iki kez olmazsa hata', () async {
    final source = FakeRangeSource(
      (prefix) => throw const PwnedPasswordsException('bağlantı'),
    );

    await expectLater(
      BreachChecker(source).check([_login(1, 'password')]),
      throwsA(isA<PwnedPasswordsException>()),
    );
    expect(source.calls, ['5BAA6', '5BAA6']);
  });

  test('HTML yanıt sonuç vermez', () async {
    final source = FakeRangeSource(
      (prefix) => '<html><body>Wi-Fi giriş sayfası</body></html>',
    );

    await expectLater(
      BreachChecker(source).check([_login(1, 'password')]),
      throwsFormatException,
    );
  });

  test('iptal edilince yeni istek başlamaz', () async {
    var cancelled = false;
    final source = FakeRangeSource((prefix) {
      cancelled = true;
      return '$pwnedPadding:0\r\n';
    });
    final items = [for (var i = 0; i < 20; i++) _login(i, 'parola-$i')];

    await expectLater(
      BreachChecker(
        source,
        concurrency: 1,
      ).check(items, isCancelled: () => cancelled),
      throwsA(isA<BreachCheckCancelled>()),
    );
    expect(source.calls, hasLength(1));
  });

  test('sızanlar: çok görülen önce, eşitse ada göre', () async {
    final items = [
      _login(1, 'a-parola', name: 'Zeplin'),
      _login(2, 'b-parola', name: 'ağaç'),
      _login(3, 'c-parola', name: 'Banka'),
      _login(4, 'c-parola', name: 'Çöpteki', trashed: true),
      _login(5, 'temiz', name: 'Temiz'),
    ];
    final result = BreachResult(
      counts: {
        pwnedHash('a-parola'): 5,
        pwnedHash('b-parola'): 5,
        pwnedHash('c-parola'): 900,
      },
      checked: {
        for (final p in ['a-parola', 'b-parola', 'c-parola', 'temiz'])
          pwnedHash(p),
      },
    );

    final leaked = leakedLogins(items, result);

    expect(
      [for (final (item, count) in leaked) (item.content.name, count)],
      [('Banka', 900), ('ağaç', 5), ('Zeplin', 5)],
    );
  });
}
