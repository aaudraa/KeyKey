import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/vault/password_policy.dart';
import 'package:keykey/features/vault/application/password_report.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

import '../../support/fake_vault_service.dart';

void main() {
  var nextId = 1;
  LoginItem login(String name, String password, {bool trashed = false}) =>
      FakeLoginRepository.item(
        LoginContent(
          name: name,
          password: password,
          trashedAt: trashed ? DateTime.utc(2026, 11, 4) : null,
        ),
        id: nextId++,
      );

  List<String> names(Iterable<LoginItem> items) =>
      items.map((item) => item.content.name).toList();

  const strong = 'Vq7#kL2m!xR9pZ4wTe';
  const shared = 'Ortak-Uzun-Parola-8xQ!';

  test('kısa ve kolay tahmin edilen parolalar zayıf sayılıyor', () {
    final report = PasswordReport.fromLogins(
      [
        login('Sağlam', strong),
        login('Kısa', 'a1B2c3'),
        login('Yaygın', 'Password123!'),
        login('Futbol', 'galatasaray1905'),
      ],
      common: {'password'},
    );

    expect(names(report.weak.map((weak) => weak.item)), [
      'Futbol',
      'Kısa',
      'Yaygın',
    ]);
    expect(report.weak.map((weak) => weak.strength), [
      PasswordStrength.weak,
      PasswordStrength.tooShort,
      PasswordStrength.weak,
    ]);
    expect(report.reused, isEmpty);
  });

  test('aynı parolayı kullanan kayıtlar gruplanıyor, büyük grup önce', () {
    final report = PasswordReport.fromLogins([
      login('Posta', shared),
      login('Banka', 'Baska-Ortak-Parola-3zR'),
      login('Oyun', shared),
      login('Forum', shared),
      login('Kredi', 'Baska-Ortak-Parola-3zR'),
      login('Tek', strong),
    ]);

    expect(report.reused.map(names), [
      ['Forum', 'Oyun', 'Posta'],
      ['Banka', 'Kredi'],
    ]);
    expect(report.weak, isEmpty);
  });

  test('çöp kutusundakiler ve boş parolalar sayılmıyor', () {
    final report = PasswordReport.fromLogins([
      login('Posta', shared),
      login('Eski Posta', shared, trashed: true),
      login('Çöpte Zayıf', '123', trashed: true),
      login('Parolasız', ''),
      login('Parolasız 2', ''),
    ]);

    expect(report.isClean, isTrue);
  });

  test('Türkçe harfler ada göre doğru sıralanıyor', () {
    final report = PasswordReport.fromLogins([
      login('Zeka', 'kisa'),
      login('İş', 'kisa2'),
      login('Çarşı', 'kisa3'),
    ]);

    expect(names(report.weak.map((weak) => weak.item)), [
      'Çarşı',
      'İş',
      'Zeka',
    ]);
  });
}
