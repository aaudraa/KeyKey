import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/crypto/kdf_params.dart';
import 'package:sodium/sodium_sumo.dart';

/// Ana paroladan Argon2id ile anahtar türetir.
final class PasswordKdf {
  const new(this._sodium);

  /// Kalibrasyonun hedeflediği açılış süresi.
  static const calibrationTarget = Duration(seconds: 1);

  /// Kalibrasyonun çıkabileceği en yüksek geçiş sayısı.
  static const maxCalibratedOpsLimit = 12;

  final SodiumSumo _sodium;

  /// Parolayı UTF-8 baytlarına çevirir. Sonuç işten sonra sıfırlanmalıdır.
  static Int8List encodePassword(String password) =>
      Int8List.fromList(utf8.encode(password));

  /// Tabandaki bellekle ve yeni rastgele tuzla parametre üretir.
  KdfParams newParams({int opsLimit = KdfParams.minOpsLimit}) => KdfParams(
    opsLimit: opsLimit,
    memLimit: KdfParams.minMemLimit,
    salt: _sodium.randombytes.buf(KdfParams.saltLength),
  );

  /// Anahtarı arayüzü dondurmamak için ayrı bir isolate'te türetir.
  ///
  /// [password] burada sıfırlanmaz, sahibi çağıran taraftır.
  Future<SecureKey> deriveKey(Int8List password, KdfParams params) {
    final sodium = _sodium;
    final salt = params.salt;
    final opsLimit = params.opsLimit;
    final memLimit = params.memLimit;
    return sodium.runIsolated((_, _) {
      // Isolate'e geçen kopyayı da işten sonra sıfırlıyoruz.
      try {
        return sodium.crypto.pwhash.callRaw(
          outLen: KdfParams.keyLength,
          password: password,
          salt: salt,
          opsLimit: opsLimit,
          memLimit: memLimit,
          alg: CryptoPwhashAlgorithm.argon2id13,
        );
      } finally {
        password.fillRange(0, password.length, 0);
      }
    });
  }

  /// Bu cihazda tabanla bir ölçüm yapıp uygun geçiş sayısını döndürür.
  Future<int> calibrateOpsLimit() async {
    final params = newParams();
    final password = Int8List.sublistView(_sodium.randombytes.buf(32));
    final stopwatch = Stopwatch()..start();
    final key = await deriveKey(password, params);
    stopwatch.stop();
    key.dispose();
    return opsLimitForMeasurement(stopwatch.elapsed);
  }

  /// Tabandaki geçiş sayısıyla ölçülen süreden hedefe uygun değeri hesaplar.
  /// Sonuç hiçbir zaman tabanın altına inmez.
  static int opsLimitForMeasurement(Duration measured) {
    if (measured <= Duration.zero) return KdfParams.minOpsLimit;
    final scaled =
        KdfParams.minOpsLimit *
        calibrationTarget.inMicroseconds ~/
        measured.inMicroseconds;
    return scaled.clamp(KdfParams.minOpsLimit, maxCalibratedOpsLimit);
  }
}
