import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/platform_api.g.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/platform_kdbx_kdf.dart';

/// Yerel tarafın verdiği hatayı taklit eder.
class _FailingApi implements ImportCryptoApi {
  new(this.code);

  final String code;

  @override
  Future<Uint8List> kdbxAesKdf(Uint8List key, Uint8List seed, int rounds) =>
      throw PlatformException(code: code);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> expectError(String code, Matcher matcher) => expectLater(
    PlatformKdbxKdf(_FailingApi(code))
        .aesKdf(key: Uint8List(32), seed: Uint8List(32), rounds: 1),
    throwsA(matcher),
  );

  test('bellek yetmezse ayrı hata', () async {
    await expectError('out-of-memory', isA<KdbxOutOfMemory>());
  });

  test('geçersiz parametre bozuk dosya sayılır', () async {
    await expectError('failed', isA<KdbxCorrupt>());
  });

  test('yerel kodun kendi hatası "bu telefonda açılamadı" olur', () async {
    await expectError('device', isA<KdbxDeviceFailure>());
    // Pigeon, Kotlin'de yakalanmayan hatayı sınıf adıyla iletir.
    await expectError('UnsatisfiedLinkError', isA<KdbxDeviceFailure>());
  });
}
