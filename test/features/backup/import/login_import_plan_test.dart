import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/backup/application/login_import_plan.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/login_content.dart';

import '../../../support/fake_vault_service.dart';

void main() {
  LoginExport exportOf(List<ImportedLogin> logins, {int skipped = 0}) =>
      LoginExport(
        source: LoginExportSource.chromeCsv,
        logins: logins,
        skipped: skipped,
      );

  const forum = ImportedLogin(
    name: 'Forum',
    username: 'ali',
    password: 'deneme-Forum-3',
    urls: ['https://forum.example.com'],
    notes: 'not',
    folder: 'Sosyal',
    favorite: true,
    fields: [(name: 'PIN', value: '1234', hidden: true)],
    totp: 'JBSWY3DPEHPK3PXP',
  );

  test('alanlar kayda aktarılıyor', () {
    final plan = planLoginImport(
      exportOf([forum], skipped: 2),
      existingLogins: const [],
      existingOtps: const [],
    );
    expect(plan.skipped, 2);
    expect(plan.skippedOtps, 0);
    final candidate = plan.candidates.single;
    expect(candidate.duplicate, isFalse);
    final content = candidate.content;
    expect(content.name, 'Forum');
    expect(content.username, 'ali');
    expect(content.password, 'deneme-Forum-3');
    expect(content.urls, ['https://forum.example.com']);
    expect(content.notes, 'not');
    expect(content.folder, 'Sosyal');
    expect(content.favorite, isTrue);
    expect(content.customFields.single.name, 'PIN');
    expect(content.customFields.single.hidden, isTrue);
    final otp = candidate.otp!;
    expect(otp.issuer, 'Forum');
    expect(otp.account, 'ali');
    expect(otp.parameters.secret, Base32.decodeLenient('JBSWY3DPEHPK3PXP'));
  });

  group('yinelenen kayıt', () {
    LoginImportCandidate against(LoginContent existing, ImportedLogin login) =>
        planLoginImport(
          exportOf([login]),
          existingLogins: [FakeLoginRepository.item(existing)],
          existingOtps: const [],
        ).candidates.single;

    test('kullanıcı adı, parola ve ortak adres aynıysa', () {
      final candidate = against(
        const LoginContent(
          name: 'Başka ad',
          username: 'ali',
          password: 'deneme-Forum-3',
          urls: ['https://m.forum.example.com', 'HTTPS://forum.example.com/'],
        ),
        forum,
      );
      expect(candidate.duplicate, isTrue);
    });

    test('parola farklıysa değil', () {
      final candidate = against(
        const LoginContent(
          name: 'Forum',
          username: 'ali',
          password: 'eski-Parola',
          urls: ['https://forum.example.com'],
        ),
        forum,
      );
      expect(candidate.duplicate, isFalse);
    });

    test('adres ortak değilse değil, ikisinde de yoksa evet', () {
      expect(
        against(
          const LoginContent(
            name: 'Forum',
            username: 'ali',
            password: 'deneme-Forum-3',
            urls: ['https://baska.example.com'],
          ),
          forum,
        ).duplicate,
        isFalse,
      );
      expect(
        against(
          const LoginContent(name: 'A', username: 'u', password: 'p'),
          const ImportedLogin(name: 'B', username: 'u', password: 'p'),
        ).duplicate,
        isTrue,
      );
    });
  });

  group('2FA', () {
    test('kasada aynı anahtar varsa yeniden eklenmiyor', () {
      final existing = OtpContent(
        parameters: OtpParameters.totp(
          secret: Base32.decodeLenient('JBSWY3DPEHPK3PXP'),
        ),
        issuer: 'Forum',
        account: 'ali',
      );
      final candidate = planLoginImport(
        exportOf([forum]),
        existingLogins: const [],
        existingOtps: [FakeOtpRepository.item(existing)],
      ).candidates.single;
      expect(candidate.otp, isNotNull);
      expect(candidate.otpAlreadySaved, isTrue);
    });

    test('dosyada aynı anahtar ikinci kez geçerse yalnızca ilki ekleniyor', () {
      final plan = planLoginImport(
        exportOf([forum, forum]),
        existingLogins: const [],
        existingOtps: const [],
      );
      expect(plan.candidates.map((c) => c.otpAlreadySaved), [false, true]);
    });

    test('okunamayan anahtar sayılıyor, kayıt yine geliyor', () {
      final plan = planLoginImport(
        exportOf([
          const ImportedLogin(name: 'Steam', totp: 'steam://ABCDEFGH'),
          const ImportedLogin(name: 'Geçersiz', totp: 'ABC!!'),
          const ImportedLogin(name: 'Bozuk', totp: 'otpauth://totp/?x=1'),
        ]),
        existingLogins: const [],
        existingOtps: const [],
      );
      expect(plan.skippedOtps, 3);
      expect(plan.candidates.map((c) => c.otp), [isNull, isNull, isNull]);
    });

    test(
      'otpauth bağlantısındaki ayarlar korunuyor, boş adlar dolduruluyor',
      () {
        final otp = otpFromImport(
          'otpauth://totp/?secret=JBSWY3DPEHPK3PXP&digits=8&period=60',
          issuer: 'Şirket',
          account: 'veli',
        )!;
        expect(otp.issuer, 'Şirket');
        expect(otp.account, 'veli');
        expect(otp.parameters.digits, 8);
        expect(otp.parameters.period, 60);
      },
    );
  });
}
