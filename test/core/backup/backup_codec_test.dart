import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late SodiumSumo sodium;
  late BackupCodec codec;
  late VaultHeader header;
  late Uint8List vaultKeyBytes;
  late SecureKey vaultKey;

  final createdAt = DateTime.utc(2026, 11, 7, 12);

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    codec = BackupCodec(sodium);
    // Kasa biçimi testlerinin sabit kasası: anahtarı bilindiği için Argon2id
    // çalıştırmadan yedek açılabiliyor.
    final fixture = jsonDecode(
      File('test/fixtures/crypto/vault-v1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    header = VaultHeader.fromJsonString(jsonEncode(fixture['header']));
    vaultKeyBytes = base64.decode(fixture['vaultKey'] as String);
    vaultKey = sodium.secureCopy(vaultKeyBytes);
  });

  tearDownAll(() => vaultKey.dispose());

  StoredRecord record(int seed, {String type = 'login', int blobSize = 300}) {
    final random = Random(seed);
    return StoredRecord(
      id: Uint8List.fromList(List.generate(16, (_) => random.nextInt(256))),
      type: type,
      blob: Uint8List.fromList(
        List.generate(blobSize, (_) => random.nextInt(256)),
      ),
      createdAt: DateTime.utc(2026, 1, 1 + seed % 28),
      updatedAt: DateTime.utc(2026, 2, 1 + seed % 28),
    );
  }

  List<StoredRecord> sampleRecords() => [
    record(1),
    record(2, type: 'otp'),
    record(3, type: 'settings', blobSize: 280),
  ];

  Future<Uint8List> encode(List<StoredRecord> records) => codec.encode(
    header: header,
    vaultKey: vaultKey,
    records: records,
    createdAt: createdAt,
  );

  Future<BackupContents> decode(Uint8List bytes, [SecureKey? key]) =>
      codec.open(codec.parse(bytes), key ?? vaultKey);

  void expectSame(List<StoredRecord> actual, List<StoredRecord> expected) {
    expect(actual, hasLength(expected.length));
    for (final (i, e) in expected.indexed) {
      expect(actual[i].id, e.id);
      expect(actual[i].type, e.type);
      expect(actual[i].blob, e.blob);
      expect(actual[i].createdAt, e.createdAt);
      expect(actual[i].updatedAt, e.updatedAt);
    }
  }

  int prefixLength(Uint8List bytes) =>
      13 + ByteData.sublistView(bytes, 9, 13).getUint32(0);

  /// Parçaların dosyadaki başlangıçları (uzunluk alanının yeri).
  List<int> chunkOffsets(Uint8List bytes) {
    final offsets = <int>[];
    var offset = prefixLength(bytes) + 24;
    while (offset < bytes.length) {
      offsets.add(offset);
      offset +=
          4 + ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
    }
    return offsets;
  }

  group('gidiş-dönüş', () {
    test('kayıtlar olduğu gibi geri geliyor', () async {
      final records = sampleRecords();
      final contents = await decode(await encode(records));
      expect(contents.createdAt, createdAt);
      expectSame(contents.records, records);
    });

    test('boş kasa da yedeklenebiliyor', () async {
      final contents = await decode(await encode(const []));
      expect(contents.records, isEmpty);
    });

    test('64 KiB üstü içerik birden çok parçaya bölünüyor', () async {
      final records = [for (var i = 0; i < 400; i++) record(i, blobSize: 600)];
      final bytes = await encode(records);
      expect(chunkOffsets(bytes).length, greaterThan(2));
      expectSame((await decode(bytes)).records, records);
    });

    test('üst bilgi kasanın üst bilgisi', () async {
      final file = codec.parse(await encode(sampleRecords()));
      expect(file.header.toJsonString(), header.toJsonString());
    });

    test('aynı içerikten iki yedek birbirinden farklı', () async {
      final a = await encode(sampleRecords());
      final b = await encode(sampleRecords());
      expect(a, isNot(b));
    });
  });

  group('tasarım belgesine uygunluk', () {
    test('baştaki alanlar belgedeki gibi', () async {
      final bytes = await encode(sampleRecords());
      expect(ascii.decode(bytes.sublist(0, 8)), 'KEYKEYBK');
      expect(bytes[8], 1);
      final length = ByteData.sublistView(bytes, 9, 13).getUint32(0);
      expect(
        utf8.decode(bytes.sublist(13, 13 + length)),
        header.toJsonString(),
      );
    });

    test('kod dışından türetilen anahtar ve AD ile açılıyor', () async {
      final bytes = await encode(sampleRecords());
      // HKDF-Expand'in tek bloklu hali HMAC-SHA256(anahtar, bağlam || 0x01).
      final digest = hashes.Hmac(
        hashes.sha256,
        vaultKeyBytes,
      ).convert([...utf8.encode('keykey/v1/backup'), 1]);
      final key = sodium.secureCopy(Uint8List.fromList(digest.bytes));
      Uint8List field(List<int> content) => Uint8List.fromList([
        ...(ByteData(4)..setUint32(0, content.length)).buffer.asUint8List(),
        ...content,
      ]);
      final prefix = bytes.sublist(0, prefixLength(bytes));
      final ad = Uint8List.fromList([
        ...field(utf8.encode('keykey/v1/backup')),
        ...field(prefix),
      ]);
      final streamHeader = bytes.sublist(prefix.length, prefix.length + 24);
      final chunks = [
        for (final offset in chunkOffsets(bytes))
          bytes.sublist(
            offset + 4,
            offset +
                4 +
                ByteData.sublistView(bytes, offset, offset + 4).getUint32(0),
          ),
      ];
      final plain = await sodium.crypto.secretStream
          .pullEx(
            cipherStream: Stream.fromIterable([
              SecretStreamCipherMessage(streamHeader),
              for (final c in chunks)
                SecretStreamCipherMessage(c, additionalData: ad),
            ]),
            key: key,
          )
          .toList();
      key.dispose();
      expect(plain.last.tag, SecretStreamMessageTag.finalPush);
      final json = jsonDecode(
        utf8.decode([for (final m in plain) ...m.message]),
      ) as Map<String, dynamic>;
      expect(json.keys, unorderedEquals(['version', 'createdAt', 'records']));
      expect(json['version'], 6);
      expect(json['createdAt'], createdAt.millisecondsSinceEpoch);
      final first = (json['records'] as List).first as Map<String, dynamic>;
      expect(
        first.keys,
        unorderedEquals(['id', 'type', 'createdAt', 'updatedAt', 'blob']),
      );
    });

    test('yedeklenen türler uygulamanın kayıt türleriyle aynı', () {
      expect(BackupCodec.legacyRecordTypes, {
        LoginRepository.recordType,
        RecordCipher.otpType,
        SettingsRepository.recordType,
      });
      expect(BackupCodec.recordTypes, {
        ...BackupCodec.legacyRecordTypes,
        VaultRecordRepository.cardType,
        VaultRecordRepository.noteType,
      });
    });

    test('yalnızca eski türler olsa da içerik sürümü 6', () async {
      // Sürüm 3 parola kaydını (passkey) 1.10 okuyamaz; içerik sürümü 6 ona
      // "daha yeni yedek" dedirtir. Şifreli kayıtların içi burada görünmediği
      // için her yedek bu sürümle yazılır.
      final contents = await decode(await encode(sampleRecords()));
      expect(contents.version, 6);
      expect(contents.sync, isNull);
    });

    test('kayıt içerik sürümleri yedeğin içerik sürümüyle birlikte', () {
      // Eski bir sürüm, tanımadığı kayıt içeriğini "bozuk" diye reddeder.
      // Bir kaydın içerik sürümü artarsa yedeğin içerik sürümü de artırılmalı
      // (güvenlik tasarımı, "Yedek"); o zaman eski sürüm "daha yeni yedek"
      // der. Bu test, o adımın unutulmaması için sürümleri sabitliyor.
      expect(
        {
          'login': LoginContent.currentVersion,
          'otp': OtpContent.currentVersion,
          'settings': AppSettings.currentVersion,
          'card': CardContent.currentVersion,
          'note': NoteContent.currentVersion,
          'payload': BackupCodec.payloadVersion,
        },
        {
          'login': 3,
          'otp': 1,
          'settings': 8,
          'card': 1,
          'note': 1,
          'payload': 6,
        },
      );
    });

    test('kart ve not içerik sürümü 6 ile gidip geliyor', () async {
      for (final type in ['card', 'note']) {
        final records = [...sampleRecords(), record(9, type: type)];
        final contents = await decode(await encode(records));
        expect(contents.version, 6, reason: type);
        expectSame(contents.records, records);
      }
    });

    test('64 MiB sınırını aşacak yedek yazılmıyor', () async {
      final big = Uint8List(25 * 1024 * 1024);
      final records = [
        for (var i = 0; i < 2; i++)
          StoredRecord(
            id: Uint8List(16)..[0] = i,
            type: 'note',
            blob: big,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
      ];
      await expectLater(
        encode(records),
        throwsA(isA<BackupTooLargeException>()),
      );
    });

    test(
      'tam 64 MiB yedek yazılıp okunuyor, bir bayt fazlası yazılmıyor',
      () async {
        // Boyut şifrelemeden önce hesaplanıyor; hesap yazılanla bayt bayt
        // aynı olmalı. Tek kaydın blob'u ve zamanlarının basamak sayısı
        // içerik uzunluğunu bayt bayt ayarlıyor.
        StoredRecord big(int blobBytes, int createdDigits, int updatedDigits) =>
            StoredRecord(
              id: Uint8List(16)..[0] = 1,
              type: 'note',
              blob: Uint8List(blobBytes),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                pow(10, createdDigits - 1).toInt(),
                isUtc: true,
              ),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                pow(10, updatedDigits - 1).toInt(),
                isUtc: true,
              ),
            );
        const tagAndLength = 4 + 17;
        const streamHeader = 24;
        const chunk = BackupCodec.chunkSize;
        const limit = BackupCodec.maxFileSize;

        // Küçük bir yedekten içeriğin sabit kısmı çıkarılıyor (tek parça).
        final probe = await encode([big(3, 1, 1)]);
        final prefix = prefixLength(probe);
        final fixed =
            probe.length - prefix - streamHeader - tagAndLength - (4 + 1 + 1);
        int sizeFor(int payload) =>
            prefix +
            streamHeader +
            payload +
            (payload + chunk - 1) ~/ chunk * tagAndLength;

        var payload =
            (limit - prefix - streamHeader) * chunk ~/ (chunk + tagAndLength);
        while (sizeFor(payload) < limit) {
          payload++;
        }
        while (sizeFor(payload) > limit) {
          payload--;
        }
        expect(sizeFor(payload), limit, reason: 'Tam sınır elde edilemedi.');

        final variable = payload - fixed;
        final groups = (variable - 2) ~/ 4;
        final digits = variable - groups * 4;
        final exact = await encode([big(groups * 3, digits - 1, 1)]);
        expect(exact.length, limit);
        expect(() => codec.parse(exact), returnsNormally);

        await expectLater(
          encode([big(groups * 3, digits, 1)]),
          throwsA(isA<BackupTooLargeException>()),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('bozuk ve değiştirilmiş dosyalar', () {
    late Uint8List bytes;

    setUpAll(() async {
      bytes = await encode([
        for (var i = 0; i < 200; i++) record(i, blobSize: 600),
      ]);
    });

    Uint8List copy() => Uint8List.fromList(bytes);

    test('yanlış anahtar açmıyor', () async {
      final other = sodium.secureRandom(32);
      await expectLater(
        decode(bytes, other),
        throwsA(isA<CorruptedDataException>()),
      );
      other.dispose();
    });

    test('son parça eksikse açılmıyor', () async {
      final offsets = chunkOffsets(bytes);
      final cut = Uint8List.sublistView(bytes, 0, offsets.last);
      await expectLater(decode(cut), throwsA(isA<CorruptedDataException>()));
    });

    test('parçanın ortasında kesilmiş dosya yapı hatası veriyor', () {
      final cut = Uint8List.sublistView(bytes, 0, bytes.length - 10);
      expect(() => codec.parse(cut), throwsA(isA<InvalidBackupException>()));
    });

    test('son parçadan sonra eklenen parça reddediliyor', () async {
      final offsets = chunkOffsets(bytes);
      final first = Uint8List.sublistView(bytes, offsets[0], offsets[1]);
      final longer = Uint8List.fromList([...bytes, ...first]);
      await expectLater(decode(longer), throwsA(isA<CorruptedDataException>()));
    });

    test('parçaların sırası değiştirilemiyor', () async {
      final offsets = chunkOffsets(bytes);
      final a = bytes.sublist(offsets[0], offsets[1]);
      final b = bytes.sublist(offsets[1], offsets[2]);
      final swapped = Uint8List.fromList([
        ...bytes.sublist(0, offsets[0]),
        ...b,
        ...a,
        ...bytes.sublist(offsets[2]),
      ]);
      await expectLater(
        decode(swapped),
        throwsA(isA<CorruptedDataException>()),
      );
    });

    test('şifreli parçada tek bit değişince açılmıyor', () async {
      final changed = copy();
      changed[chunkOffsets(bytes)[1] + 40] ^= 0x01;
      await expectLater(
        decode(changed),
        throwsA(isA<CorruptedDataException>()),
      );
    });

    test('akış başlığında tek bit değişince açılmıyor', () async {
      final changed = copy();
      changed[prefixLength(bytes) + 3] ^= 0x80;
      await expectLater(
        decode(changed),
        throwsA(isA<CorruptedDataException>()),
      );
    });

    test('üst bilgide biçime uyan bir değişiklik içeriği açtırmıyor', () async {
      // Tuzun bir harfi değişiyor; JSON hâlâ geçerli ama AD tutmuyor.
      final text = latin1.decode(bytes);
      final salt =
          ((jsonDecode(header.toJsonString()) as Map)['kdf'] as Map)['salt']
              as String;
      final changedSalt = (salt[0] == 'A' ? 'B' : 'A') + salt.substring(1);
      final changed = Uint8List.fromList(
        latin1.encode(text.replaceFirst(salt, changedSalt)),
      );
      final file = codec.parse(changed);
      await expectLater(
        codec.open(file, vaultKey),
        throwsA(isA<CorruptedDataException>()),
      );
    });

    test('sihir, sürüm ve uzunluk denetleniyor', () {
      void expectInvalid(Uint8List value) => expect(
        () => codec.parse(value),
        throwsA(isA<InvalidBackupException>()),
      );
      expectInvalid(Uint8List(0));
      expectInvalid(Uint8List.fromList(utf8.encode('KEYKEY')));
      expectInvalid(copy()..[0] = 0x6B);
      expectInvalid(copy()..[8] = 0);
      expect(
        () => codec.parse(copy()..[8] = 2),
        throwsA(isA<NewerBackupException>()),
      );
      // Üst bilgi uzunluğu 0 ve tavanın üstü.
      expectInvalid(copy()..setRange(9, 13, [0, 0, 0, 0]));
      expectInvalid(copy()..setRange(9, 13, [0, 0, 0x10, 0x01]));
      // Akış başlığından sonra hiç parça yok.
      expectInvalid(Uint8List.sublistView(bytes, 0, prefixLength(bytes) + 24));
      // Parça uzunluğu sınırın üstünde.
      final offset = chunkOffsets(bytes).first;
      expectInvalid(copy()..setRange(offset, offset + 4, [0, 2, 0, 0]));
    });

    test('64 MiB üstü dosya okunmuyor', () {
      expect(
        () => codec.parse(Uint8List(BackupCodec.maxFileSize + 1)),
        throwsA(isA<InvalidBackupException>()),
      );
    });

    test(
      'rastgele bozulan dosyalar yalnızca kendi hatalarını veriyor',
      () async {
        final random = Random(7);
        final small = await encode(sampleRecords());
        for (var round = 0; round < 300; round++) {
          final changed = Uint8List.fromList(small);
          final edits = 1 + random.nextInt(4);
          for (var i = 0; i < edits; i++) {
            changed[random.nextInt(changed.length)] = random.nextInt(256);
          }
          final input = random.nextInt(5) == 0
              ? Uint8List.sublistView(
                  changed,
                  0,
                  random.nextInt(changed.length),
                )
              : changed;
          try {
            await decode(input);
          } on InvalidBackupException {
            // Beklenen.
          } on CorruptedDataException {
            // Beklenen.
          }
        }
      },
    );
  });

  group('içerik doğrulaması', () {
    /// Belgeye göre ama istenen düz metinle bir yedek üretir.
    Future<Uint8List> withPayload(Object payload) async {
      final good = await encode(const []);
      final prefix = good.sublist(0, prefixLength(good));
      final digest = hashes.Hmac(
        hashes.sha256,
        vaultKeyBytes,
      ).convert([...utf8.encode('keykey/v1/backup'), 1]);
      final key = sodium.secureCopy(Uint8List.fromList(digest.bytes));
      Uint8List field(List<int> content) => Uint8List.fromList([
        ...(ByteData(4)..setUint32(0, content.length)).buffer.asUint8List(),
        ...content,
      ]);
      final ad = Uint8List.fromList([
        ...field(utf8.encode('keykey/v1/backup')),
        ...field(prefix),
      ]);
      final text = payload is String ? payload : jsonEncode(payload);
      final bytes = Uint8List.fromList(utf8.encode(text));
      const size = BackupCodec.chunkSize;
      final messages = [
        for (var i = 0; i == 0 || i < bytes.length; i += size)
          SecretStreamPlainMessage(
            Uint8List.sublistView(bytes, i, min(i + size, bytes.length)),
            additionalData: ad,
            tag: i + size >= bytes.length
                ? SecretStreamMessageTag.finalPush
                : SecretStreamMessageTag.message,
          ),
      ];
      final cipher = await sodium.crypto.secretStream
          .pushEx(messageStream: Stream.fromIterable(messages), key: key)
          .toList();
      key.dispose();
      return Uint8List.fromList([
        ...prefix,
        ...cipher.first.message,
        for (final c in cipher.skip(1)) ...[
          ...(ByteData(4)..setUint32(0, c.message.length)).buffer.asUint8List(),
          ...c.message,
        ],
      ]);
    }

    Map<String, Object> entry({
      String id = 'AAECAwQFBgcICQoLDA0ODw==',
      String type = 'login',
    }) => {
      'id': id,
      'type': type,
      'createdAt': 1,
      'updatedAt': 2,
      'blob': 'AQID',
    };

    Map<String, Object> payload(List<Object> records) => {
      'version': 1,
      'createdAt': 3,
      'records': records,
    };

    Future<void> expectInvalid(Object value) async {
      await expectLater(
        decode(await withPayload(value)),
        throwsA(isA<InvalidBackupException>()),
      );
    }

    test('elle üretilen geçerli içerik açılıyor', () async {
      final contents = await decode(await withPayload(payload([entry()])));
      expect(contents.records.single.blob, [1, 2, 3]);
    });

    test('daha yeni içerik sürümü ayrı hatayla reddediliyor', () async {
      await expectLater(
        decode(await withPayload({...payload([]), 'version': 7})),
        throwsA(isA<NewerBackupException>()),
      );
    });

    test(
      'daha yeni içerik sürümü alanları değişse de yeni diye bildiriliyor',
      () async {
        // Sonraki bir sürüm kök alanlarını değiştirebilir; bu sürüm onu
        // "bozuk" sanmamalı.
        await expectLater(
          decode(
            await withPayload({...payload([]), 'version': 7, 'app': '1.5.0'}),
          ),
          throwsA(isA<NewerBackupException>()),
        );
        await expectLater(
          decode(await withPayload({'version': 7, 'items': <Object>[]})),
          throwsA(isA<NewerBackupException>()),
        );
      },
    );

    test('sürüm 2-6 içerikte kart ve not açılıyor', () async {
      for (final version in [2, 3, 4, 5, 6]) {
        final contents = await decode(
          await withPayload({
            ...payload([
              entry(type: 'card'),
              entry(id: 'AQECAwQFBgcICQoLDA0ODw==', type: 'note'),
            ]),
            'version': version,
          }),
        );
        expect(contents.version, version);
        expect(contents.records.map((r) => r.type), ['card', 'note']);
      }
    });

    test('bilinmeyen sürüm, eksik ve fazla alan reddediliyor', () async {
      await expectInvalid({...payload([]), 'version': 0});
      await expectInvalid({'version': 1, 'records': <Object>[]});
      await expectInvalid({...payload([]), 'ek': true});
      await expectInvalid(
        payload([
          {...entry(), 'ek': 1},
        ]),
      );
      await expectInvalid('[]');
      await expectInvalid('{bozuk');
    });

    test('bilinmeyen tür ve yinelenen kimlik reddediliyor', () async {
      await expectInvalid(payload([entry(type: 'card')]));
      await expectInvalid(payload([entry(type: 'note')]));
      for (final version in [2, 3, 4]) {
        await expectInvalid({
          ...payload([entry(type: 'kimlik')]),
          'version': version,
        });
      }
      await expectInvalid(payload([entry(), entry()]));
      await expectInvalid(payload([entry(id: 'AAEC')]));
    });

    test('Base64 tek gösterimli olmalı', () async {
      await expectInvalid(payload([entry(id: 'AAECAwQFBgcICQoLDA0ODw')]));
      await expectInvalid(payload([entry(id: 'AAECAwQFBgcICQoLDA0OD-==')]));
    });

    test('zaman negatif veya sayı dışı olamaz', () async {
      await expectInvalid({...payload([]), 'createdAt': -1});
      await expectInvalid({...payload([]), 'createdAt': '3'});
    });

    group('senkron bilgisi', () {
      Map<String, Object?> sync({
        Object? device = 'a1b2c3',
        Object? deviceName = 'SM-G780G',
        List<Object> deleted = const [],
      }) => {
        'device': device,
        'deviceName': deviceName,
        'passwordChangedAt': 5,
        'recoveryChangedAt': null,
        'deleted': deleted,
      };

      Map<String, Object?> tombstone([
        String id = 'AQECAwQFBgcICQoLDA0ODw==',
      ]) => {'id': id, 'deletedAt': 4};

      Map<String, Object?> v4(List<Object> records, Map<String, Object?> s) => {
        'version': 4,
        'createdAt': 3,
        'records': records,
        'sync': s,
      };

      test('elle üretilen senkron dosyası açılıyor', () async {
        final contents = await decode(
          await withPayload(v4([entry()], sync(deleted: [tombstone()]))),
        );
        expect(contents.version, 4);
        expect(contents.sync?.device, 'a1b2c3');
        expect(contents.sync?.deviceName, 'SM-G780G');
        expect(
          contents.sync?.passwordChangedAt,
          DateTime.fromMillisecondsSinceEpoch(5, isUtc: true),
        );
        expect(contents.sync?.recoveryChangedAt, isNull);
        expect(contents.sync?.deleted.single.id, hasLength(16));
        expect(
          contents.sync?.deleted.single.deletedAt,
          DateTime.fromMillisecondsSinceEpoch(4, isUtc: true),
        );
      });

      test('sürüm 4 ve sonrası senkron bilgisi taşıyabilir', () async {
        for (final version in [5, 6]) {
          final contents = await decode(
            await withPayload({
              ...v4([entry()], sync()),
              'version': version,
            }),
          );
          expect(contents.sync?.device, 'a1b2c3', reason: '$version');
        }
        await expectInvalid({
          ...payload([entry()]),
          'sync': sync(),
        });
        await expectInvalid({
          ...payload([entry()]),
          'version': 3,
          'sync': sync(),
        });
      });

      test('ayar kaydı ve yinelenen silme kaydı reddediliyor', () async {
        await expectInvalid(v4([entry(type: 'settings')], sync()));
        await expectInvalid(
          v4([entry()], sync(deleted: [tombstone(), tombstone()])),
        );
      });

      test('cihaz kimliği ve adı denetleniyor', () async {
        await expectInvalid(v4([entry()], sync(device: 'A1B2C3')));
        await expectInvalid(v4([entry()], sync(device: 'a1b2c')));
        await expectInvalid(v4([entry()], sync(device: null)));
        await expectInvalid(v4([entry()], sync(deviceName: 'x' * 65)));
        await expectInvalid(v4([entry()], sync(deviceName: 3)));
        final named = await decode(
          await withPayload(v4([entry()], sync(deviceName: null))),
        );
        expect(named.sync?.deviceName, isNull);
      });

      test('eksik, fazla ve bozuk alanlar reddediliyor', () async {
        await expectInvalid(v4([entry()], {...sync(), 'ek': 1}));
        await expectInvalid(v4([entry()], {...sync()}..remove('deleted')));
        await expectInvalid(
          v4([entry()], {...sync(), 'passwordChangedAt': -1}),
        );
        await expectInvalid(
          v4(
            [entry()],
            sync(
              deleted: [
                {...tombstone(), 'deletedAt': '4'},
              ],
            ),
          ),
        );
        await expectInvalid(v4([entry()], sync(deleted: [tombstone('AAEC')])));
      });

      test('kayıtlar ve silme kayıtları birlikte sınıra sayılıyor', () async {
        final deleted = [
          for (var i = 0; i < BackupCodec.maxRecords; i++)
            {
              'id': base64.encode(
                Uint8List(16)..buffer.asByteData().setUint32(0, i),
              ),
              'deletedAt': 4,
            },
        ];
        await expectInvalid(
          v4([entry(id: 'AP8CAwQFBgcICQoLDA0ODw==')], sync(deleted: deleted)),
        );
      });

      test('yazılan senkron bilgisi geri geliyor', () async {
        final info = SyncInfo(
          device: 'a1b2c3',
          deviceName: 'SM-G780G',
          passwordChangedAt: createdAt,
          deleted: [
            StoredTombstone(id: Uint8List(16)..[0] = 9, deletedAt: createdAt),
          ],
        );
        final bytes = await codec.encode(
          header: header,
          vaultKey: vaultKey,
          records: [
            record(1),
            record(2, type: 'otp'),
          ],
          createdAt: createdAt,
          sync: info,
        );
        final contents = await decode(bytes);
        expect(contents.version, 6);
        expect(contents.records, hasLength(2));
        expect(contents.sync?.device, 'a1b2c3');
        expect(contents.sync?.passwordChangedAt, createdAt);
        expect(contents.sync?.recoveryChangedAt, isNull);
        expect(contents.sync?.deleted.single.id[0], 9);
      });

      test('senkron dosyasına ayar kaydı yazılmıyor', () {
        expect(
          codec.encode(
            header: header,
            vaultKey: vaultKey,
            records: sampleRecords(),
            createdAt: createdAt,
            sync: const SyncInfo(device: 'a1b2c3'),
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
