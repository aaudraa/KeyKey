import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/crypto/associated_data.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:sodium/sodium_sumo.dart';

/// Açılmış bir yedeğin içeriği.
///
/// Kayıtlar hâlâ kayıt biçiminde şifrelidir; yedeğin kasa anahtarıyla
/// çözülürler.
final class BackupContents {
  const new({required this.createdAt, required this.records});

  final DateTime createdAt;
  final List<StoredRecord> records;
}

/// Yapısı denetlenmiş ama henüz açılmamış bir yedek dosyası.
///
/// Üst bilgi kasanın üst bilgisidir; yuvalarından biri açılınca elde edilen
/// kasa anahtarıyla [BackupCodec.open] içeriği çözer.
final class BackupFile {
  const new _(this.header, this._prefix, this._streamHeader, this._chunks);

  final VaultHeader header;

  /// Dosyanın başından üst bilginin sonuna kadarki baytlar. Her parçanın ek
  /// doğrulama verisine girer.
  final Uint8List _prefix;
  final Uint8List _streamHeader;
  final List<Uint8List> _chunks;
}

/// `.keykey` yedek biçimini yazar ve okur.
///
/// Biçim güvenlik tasarımı belgesinin "Yedek biçimi" bölümündedir. Bu sınıf
/// kayıtların içini bilmez, onları veritabanındaki şifreli halleriyle taşır.
final class BackupCodec {
  const new(this._sodium);

  static const magic = 'KEYKEYBK';
  static const formatVersion = 1;
  static const payloadVersion = 1;
  static const backupContext = 'keykey/v1/backup';

  static const int maxFileSize = 64 * 1024 * 1024;
  static const maxHeaderLength = 4096;
  static const maxRecords = 100000;
  static const int chunkSize = 64 * 1024;

  /// Yedeğe girebilen kayıt türleri. Parola, 2FA ve ayar kayıtları.
  static const Set<String> recordTypes = {'login', 'otp', 'settings'};

  static const _keyLength = 32;
  static const _recordIdLength = 16;
  static const _lengthBytes = 4;

  final SodiumSumo _sodium;

  SecretStream get _stream => _sodium.crypto.secretStream;

  /// Kasanın yedeğini üretir.
  Future<Uint8List> encode({
    required VaultHeader header,
    required SecureKey vaultKey,
    required List<StoredRecord> records,
    required DateTime createdAt,
  }) async {
    if (records.length > maxRecords) {
      throw ArgumentError.value(records.length, 'records', 'Çok fazla kayıt');
    }
    final headerBytes = utf8.encode(header.toJsonString());
    if (headerBytes.length > maxHeaderLength) {
      throw ArgumentError.value(headerBytes.length, 'header', 'Çok uzun');
    }
    final prefix = BytesBuilder(copy: false)
      ..add(ascii.encode(magic))
      ..addByte(formatVersion)
      ..add(_uint32(headerBytes.length))
      ..add(headerBytes);
    final prefixBytes = prefix.takeBytes();

    final payload = utf8.encode(_payloadJson(records, createdAt));
    try {
      final ad = _associatedData(prefixBytes);
      final messages = <SecretStreamPlainMessage>[];
      for (var start = 0; start < payload.length; start += chunkSize) {
        final end = start + chunkSize < payload.length
            ? start + chunkSize
            : payload.length;
        messages.add(
          SecretStreamPlainMessage(
            Uint8List.sublistView(payload, start, end),
            additionalData: ad,
            tag: end == payload.length
                ? SecretStreamMessageTag.finalPush
                : SecretStreamMessageTag.message,
          ),
        );
      }
      final key = _deriveKey(vaultKey);
      final List<SecretStreamCipherMessage> cipher;
      try {
        cipher = await _stream
            .pushEx(messageStream: Stream.fromIterable(messages), key: key)
            .toList();
      } finally {
        key.dispose();
      }
      // İlk mesaj akış başlığıdır, gerisi parçalar.
      final out = BytesBuilder(copy: false)
        ..add(prefixBytes)
        ..add(cipher.first.message);
      for (final chunk in cipher.skip(1)) {
        out
          ..add(_uint32(chunk.message.length))
          ..add(chunk.message);
      }
      return out.takeBytes();
    } finally {
      payload.fillRange(0, payload.length, 0);
    }
  }

  /// Dosyanın yapısını denetler, şifreli kısma dokunmaz.
  ///
  /// Yedek değilse, sürümü desteklenmiyorsa veya yapısı bozuksa
  /// [InvalidBackupException] fırlatır.
  BackupFile parse(Uint8List bytes) {
    if (bytes.length > maxFileSize) {
      throw const InvalidBackupException('Dosya çok büyük.');
    }
    final reader = _Reader(bytes);
    final fileMagic = reader.take(magic.length);
    if (fileMagic == null ||
        ascii.decode(fileMagic, allowInvalid: true) != magic) {
      throw const InvalidBackupException('KeyKey yedeği değil.');
    }
    final version = reader.take(1);
    if (version == null || version[0] != formatVersion) {
      throw const InvalidBackupException('Desteklenmeyen yedek sürümü.');
    }
    final headerLength = reader.uint32();
    if (headerLength == null ||
        headerLength == 0 ||
        headerLength > maxHeaderLength) {
      throw const InvalidBackupException('Geçersiz üst bilgi uzunluğu.');
    }
    final headerBytes = reader.take(headerLength);
    if (headerBytes == null) {
      throw const InvalidBackupException('Dosya eksik.');
    }
    final VaultHeader header;
    try {
      header = VaultHeader.fromJsonString(utf8.decode(headerBytes));
    } on FormatException {
      throw const InvalidBackupException('Üst bilgi okunamadı.');
    } on InvalidVaultHeaderException {
      throw const InvalidBackupException('Üst bilgi okunamadı.');
    }
    final prefix = Uint8List.sublistView(bytes, 0, reader.offset);

    final streamHeader = reader.take(_stream.headerBytes);
    if (streamHeader == null) {
      throw const InvalidBackupException('Dosya eksik.');
    }
    final maxCipherLength = chunkSize + _stream.aBytes;
    final chunks = <Uint8List>[];
    while (!reader.isDone) {
      final length = reader.uint32();
      if (length == null ||
          length < _stream.aBytes ||
          length > maxCipherLength) {
        throw const InvalidBackupException('Geçersiz parça uzunluğu.');
      }
      final chunk = reader.take(length);
      if (chunk == null) throw const InvalidBackupException('Dosya eksik.');
      chunks.add(chunk);
    }
    if (chunks.isEmpty) throw const InvalidBackupException('Dosya eksik.');
    return BackupFile._(header, prefix, streamHeader, chunks);
  }

  /// Yedeğin içeriğini [vaultKey] ile çözer.
  ///
  /// [vaultKey], [BackupFile.header] yuvalarından biri açılarak elde edilir.
  /// Dosya kesilmiş, değiştirilmiş veya sonuna veri eklenmişse
  /// [CorruptedDataException]; içerik biçime uymuyorsa
  /// [InvalidBackupException] fırlatır.
  Future<BackupContents> open(BackupFile file, SecureKey vaultKey) async {
    final plain = await _decryptChunks(file, vaultKey);
    final payload = BytesBuilder(copy: false);
    for (final message in plain) {
      payload.add(message.message);
    }
    final bytes = payload.takeBytes();
    try {
      return _parsePayload(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      for (final message in plain) {
        message.message.fillRange(0, message.message.length, 0);
      }
    }
  }

  /// Parçaları sırayla çözer. Yalnızca son parça FINAL olabilir; FINAL'den
  /// sonra parça kalırsa veya son parça FINAL değilse dosya bozuk sayılır.
  ///
  /// Parçalar akışa tek tek verilir, böylece FINAL'den sonraki parça
  /// kütüphaneye hiç ulaşmadan reddedilir.
  Future<List<SecretStreamPlainMessage>> _decryptChunks(
    BackupFile file,
    SecureKey vaultKey,
  ) async {
    final ad = _associatedData(file._prefix);
    final key = _deriveKey(vaultKey);
    final input = StreamController<SecretStreamCipherMessage>();
    final output = StreamIterator(
      _stream.pullEx(cipherStream: input.stream, key: key),
    );
    final plain = <SecretStreamPlainMessage>[];
    try {
      input.add(SecretStreamCipherMessage(file._streamHeader));
      for (final (index, chunk) in file._chunks.indexed) {
        input.add(SecretStreamCipherMessage(chunk, additionalData: ad));
        if (!await output.moveNext()) throw const CorruptedDataException();
        final message = output.current;
        final isLast = index == file._chunks.length - 1;
        final expected = isLast
            ? SecretStreamMessageTag.finalPush
            : SecretStreamMessageTag.message;
        if (message.tag != expected) throw const CorruptedDataException();
        plain.add(message);
      }
      // Kapanışı beklemek kilitlenir: yineleyici akışı duraklatıyor.
      unawaited(input.close());
      if (await output.moveNext()) throw const CorruptedDataException();
      return plain;
    } on Object catch (error) {
      for (final message in plain) {
        message.message.fillRange(0, message.message.length, 0);
      }
      if (error is SodiumException || error is StreamClosedEarlyException) {
        throw const CorruptedDataException();
      }
      rethrow;
    } finally {
      await output.cancel();
      key.dispose();
    }
  }

  SecureKey _deriveKey(SecureKey vaultKey) => _sodium.crypto.kdfHkdfSha256
      .expand(masterKey: vaultKey, context: backupContext, outLen: _keyLength);

  static Uint8List _associatedData(Uint8List prefix) =>
      buildAssociatedData([backupContext, prefix]);

  static String _payloadJson(List<StoredRecord> records, DateTime createdAt) {
    final ids = <String>{};
    final entries = <Map<String, Object>>[];
    for (final record in records) {
      if (!recordTypes.contains(record.type)) {
        throw ArgumentError.value(record.type, 'type', 'Yedeklenmeyen tür');
      }
      final id = base64.encode(record.id);
      if (record.id.length != _recordIdLength || !ids.add(id)) {
        throw ArgumentError.value(id, 'id', 'Geçersiz veya yinelenen kimlik');
      }
      entries.add({
        'id': id,
        'type': record.type,
        'createdAt': record.createdAt.millisecondsSinceEpoch,
        'updatedAt': record.updatedAt.millisecondsSinceEpoch,
        'blob': base64.encode(record.blob),
      });
    }
    return jsonEncode({
      'version': payloadVersion,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'records': entries,
    });
  }

  static BackupContents _parsePayload(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const InvalidBackupException('İçerik okunamadı.');
    }
    final root = _object(decoded, const {'version', 'createdAt', 'records'});
    if (root['version'] != payloadVersion) {
      throw const InvalidBackupException('Desteklenmeyen içerik sürümü.');
    }
    final list = root['records'];
    if (list is! List<Object?> || list.length > maxRecords) {
      throw const InvalidBackupException('Geçersiz kayıt listesi.');
    }
    final ids = <String>{};
    final records = <StoredRecord>[];
    for (final item in list) {
      final entry = _object(item, const {
        'id',
        'type',
        'createdAt',
        'updatedAt',
        'blob',
      });
      final type = entry['type'];
      if (type is! String || !recordTypes.contains(type)) {
        throw const InvalidBackupException('Desteklenmeyen kayıt türü.');
      }
      final id = _bytes(entry['id']);
      if (id.length != _recordIdLength || !ids.add(entry['id']! as String)) {
        throw const InvalidBackupException('Geçersiz kayıt kimliği.');
      }
      records.add(
        StoredRecord(
          id: id,
          type: type,
          blob: _bytes(entry['blob']),
          createdAt: _time(entry['createdAt']),
          updatedAt: _time(entry['updatedAt']),
        ),
      );
    }
    return BackupContents(
      createdAt: _time(root['createdAt']),
      records: records,
    );
  }

  static Map<String, Object?> _object(Object? value, Set<String> keys) {
    if (value is! Map<String, Object?> ||
        value.length != keys.length ||
        !value.keys.every(keys.contains)) {
      throw const InvalidBackupException('Geçersiz alanlar.');
    }
    return value;
  }

  static Uint8List _bytes(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const InvalidBackupException('Geçersiz ikili alan.');
    }
    final Uint8List bytes;
    try {
      bytes = base64.decode(value);
    } on FormatException {
      throw const InvalidBackupException('Geçersiz Base64.');
    }
    // Tek geçerli gösterim: dolgulu, standart alfabe.
    if (base64.encode(bytes) != value) {
      throw const InvalidBackupException('Geçersiz Base64.');
    }
    return bytes;
  }

  static DateTime _time(Object? value) {
    if (value is! int || value < 0) {
      throw const InvalidBackupException('Geçersiz zaman.');
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  static Uint8List _uint32(int value) =>
      (ByteData(_lengthBytes)..setUint32(0, value)).buffer.asUint8List();
}

/// Bayt dizisini baştan sona okur. Yetmeyen okumada `null` döner.
final class _Reader {
  new(this._bytes);

  final Uint8List _bytes;
  int offset = 0;

  bool get isDone => offset == _bytes.length;

  Uint8List? take(int length) {
    if (length < 0 || _bytes.length - offset < length) return null;
    final view = Uint8List.sublistView(_bytes, offset, offset + length);
    offset += length;
    return view;
  }

  int? uint32() {
    final bytes = take(BackupCodec._lengthBytes);
    if (bytes == null) return null;
    return ByteData.sublistView(bytes).getUint32(0);
  }
}
