import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/backup/application/login_import_plan.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';
import 'package:keykey/features/vault/data/note_content.dart';

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

  group('kart ve not', () {
    final card = CardContent(name: 'Maaş', number: '4111111111111111');
    final note = NoteContent(name: 'Wi-Fi', text: 'parola: kapi');

    LoginImportPlan planOf({
      List<ImportedCard> cards = const [],
      List<NoteContent> notes = const [],
      List<CardContent> existingCards = const [],
      List<NoteContent> existingNotes = const [],
    }) => planLoginImport(
      LoginExport(
        source: LoginExportSource.bitwardenJson,
        logins: const [],
        cards: cards,
        notes: notes,
        skipped: 0,
      ),
      existingLogins: const [],
      existingOtps: const [],
      existingCards: [
        for (final c in existingCards) FakeRecordRepository.item(c),
      ],
      existingNotes: [
        for (final n in existingNotes) FakeRecordRepository.item(n),
      ],
    );

    test('kart ve not adaylara giriyor, düzeltme işareti taşınıyor', () {
      final plan = planOf(
        cards: [ImportedCard(content: card, adjusted: true)],
        notes: [note],
      );
      expect(plan.cards.single.content, same(card));
      expect(plan.cards.single.adjusted, isTrue);
      expect(plan.cards.single.duplicate, isFalse);
      expect(plan.notes.single.content, same(note));
      expect(plan.notes.single.duplicate, isFalse);
    });

    test('kasada aynı ad ve numaralı kart yinelenen sayılıyor', () {
      expect(
        planOf(
          cards: [ImportedCard(content: card, adjusted: false)],
          existingCards: [
            CardContent(name: ' Maaş ', number: '4111111111111111'),
          ],
        ).cards.single.duplicate,
        isTrue,
      );
      expect(
        planOf(
          cards: [ImportedCard(content: card, adjusted: false)],
          existingCards: [
            CardContent(name: 'Maaş', number: '5555555555554444'),
          ],
        ).cards.single.duplicate,
        isFalse,
      );
    });

    test('kasada aynı ad ve metinli not yinelenen sayılıyor', () {
      expect(
        planOf(notes: [note], existingNotes: [note]).notes.single.duplicate,
        isTrue,
      );
      expect(
        planOf(
          notes: [note],
          existingNotes: [NoteContent(name: 'Wi-Fi', text: 'eski')],
        ).notes.single.duplicate,
        isFalse,
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

    test(
      'dosyada aynı anahtar iki kez geçse de plan ikisini de ekleyebilir',
      () {
        // Hangisinin seçileceği kaydederken belli olur; plan yalnızca kasada
        // olanı sayar.
        final plan = planLoginImport(
          exportOf([forum, forum]),
          existingLogins: const [],
          existingOtps: const [],
        );
        expect(plan.candidates.map((c) => c.otpAlreadySaved), [false, false]);
      },
    );

    test('seçilenler arasında aynı anahtar bir kez ekleniyor', () {
      final plan = planLoginImport(
        exportOf([forum, forum]),
        existingLogins: const [],
        existingOtps: const [],
      );
      final ids = [Uint8List(16)..[15] = 1, Uint8List(16)..[15] = 2];
      final otps = importedOtps(plan.candidates, ids);
      expect(otps, hasLength(1));
      expect(otps.single.loginId, ids.first);
    });

    test('ilk aday seçilmezse anahtar ikinciyle ekleniyor', () {
      // N1: ilki kasadaki bir girişe benzediği için seçilmemişse 2FA
      // anahtarı hiçbir yere kaydedilmiyordu.
      final plan = planLoginImport(
        exportOf([forum, forum]),
        existingLogins: const [],
        existingOtps: const [],
      );
      final id = Uint8List(16)..[15] = 2;
      final otps = importedOtps([plan.candidates[1]], [id]);
      expect(otps.single.loginId, id);
    });

    test("Bitwarden'ın steam:// anahtarı Steam hesabı oluyor", () {
      final otp = otpFromImport(
        ' steam://63bedwcqzktqwpesarierl5dttqfcjtk ',
        issuer: 'Steam',
        account: 'oyuncu',
      )!;
      expect(
        otp.parameters,
        OtpParameters.steam(
          secret: Base32.decodeCanonical('63BEDWCQZKTQWPESARIERL5DTTQFCJTK'),
        ),
      );
      expect(otp.issuer, 'Steam');
      expect(otp.account, 'oyuncu');
    });

    test('okunamayan anahtar sayılıyor, kayıt yine geliyor', () {
      final plan = planLoginImport(
        exportOf([
          // Tanınmayan biçim (Steam 1.7.0'dan beri okunuyor).
          const ImportedLogin(name: 'Yandex', totp: 'yandex://ABCDEFGH'),
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

  test("passkey'ler kayda geçiyor ve sayılıyor", () {
    LoginPasskey key(int id) => LoginPasskey(
      credentialId: Uint8List.fromList([id]),
      rpId: 'github.com',
      userHandle: Uint8List(0),
      userName: 'ali',
      userDisplayName: '',
      privateKey: Uint8List.fromList([id]),
      createdAt: DateTime.utc(2026),
    );
    final plan = planLoginImport(
      LoginExport(
        source: LoginExportSource.bitwardenJson,
        logins: [
          ImportedLogin(name: 'GitHub', passkeys: [key(1), key(2)]),
          ImportedLogin(name: 'Site', password: 'p', passkeys: [key(3)]),
          forum,
        ],
        skipped: 0,
        skippedPasskeys: 4,
      ),
      existingLogins: const [],
      existingOtps: const [],
    );

    expect(plan.candidates[0].content.passkeys.map((p) => p.credentialId), [
      [1],
      [2],
    ]);
    expect(plan.candidates[2].content.passkeys, isEmpty);
    expect(plan.passkeys, 3);
    expect(plan.skippedPasskeys, 4);
  });
}
