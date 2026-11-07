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
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
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
      expect(json['version'], 1);
      expect(json['createdAt'], createdAt.millisecondsSinceEpoch);
      final first = (json['records'] as List).first as Map<String, dynamic>;
      expect(
        first.keys,
        unorderedEquals(['id', 'type', 'createdAt', 'updatedAt', 'blob']),
      );
    });

    test('yedeklenen türler uygulamanın kayıt türleriyle aynı', () {
      expect(BackupCodec.recordTypes, {
        LoginRepository.recordType,
        RecordCipher.otpType,
        SettingsRepository.recordType,
      });
    });
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
      expectInvalid(copy()..[8] = 2);
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
      final cipher = await sodium.crypto.secretStream
          .pushEx(
            messageStream: Stream.value(
              SecretStreamPlainMessage(
                Uint8List.fromList(utf8.encode(text)),
                additionalData: ad,
                tag: SecretStreamMessageTag.finalPush,
              ),
            ),
            key: key,
          )
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

    test('bilinmeyen sürüm, eksik ve fazla alan reddediliyor', () async {
      await expectInvalid({...payload([]), 'version': 2});
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
  });
}
