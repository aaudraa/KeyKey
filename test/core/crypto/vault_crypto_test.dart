import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/associated_data.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/kdf_params.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const password = 'doğru-parola-ığüşöç';
  const otherPassword = 'yeni-parola';

  late SodiumSumo sodium;
  late VaultCrypto crypto;
  late CreatedVault vault;
  late Uint8List vaultKeyBytes;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    crypto = VaultCrypto(sodium);
    vault = await crypto.createVault(password);
    vaultKeyBytes = vault.vaultKey.extractBytes();
  });

  tearDownAll(() => vault.vaultKey.dispose());

  Uint8List bytesOf(SecureKey key) {
    addTearDown(key.dispose);
    return key.extractBytes();
  }

  Matcher throwsWrongSecret() => throwsA(isA<WrongSecretException>());

  Uint8List flipBit(Uint8List data, [int index = 0]) =>
      Uint8List.fromList(data)..[index] ^= 1;

  VaultHeader copyHeader({
    Uint8List? vaultId,
    KdfParams? kdf,
    WrappedKey? passwordSlot,
    WrappedKey? recoverySlot,
  }) {
    final header = vault.header;
    return VaultHeader(
      vaultId: vaultId ?? header.vaultId,
      kdf: kdf ?? header.kdf,
      passwordSlot: passwordSlot ?? header.passwordSlot,
      recoverySlot: recoverySlot ?? header.recoverySlot,
    );
  }

  group('kasa oluşturma', () {
    test('alan uzunlukları tasarımla aynı', () {
      final header = vault.header;

      expect(vaultKeyBytes, hasLength(32));
      expect(header.vaultId, hasLength(16));
      expect(header.kdf.salt, hasLength(16));
      expect(header.kdf.opsLimit, KdfParams.minOpsLimit);
      expect(header.kdf.memLimit, KdfParams.minMemLimit);
      expect(header.passwordSlot.nonce, hasLength(24));
      expect(header.passwordSlot.cipherText, hasLength(48));
      expect(header.recoverySlot.nonce, hasLength(24));
      expect(header.recoverySlot.cipherText, hasLength(48));
    });

    test('her kasa farklı anahtar, kimlik, tuz ve nonce kullanıyor', () async {
      final second = await crypto.createVault(password);
      addTearDown(second.vaultKey.dispose);

      expect(second.vaultKey.extractBytes(), isNot(vaultKeyBytes));
      expect(second.header.vaultId, isNot(vault.header.vaultId));
      expect(second.header.kdf.salt, isNot(vault.header.kdf.salt));
      expect(
        second.header.passwordSlot.nonce,
        isNot(vault.header.passwordSlot.nonce),
      );
      expect(second.recoveryKeyText, isNot(vault.recoveryKeyText));
    });

    test('kasa anahtarı üst bilgide açık halde durmuyor', () {
      final header = vault.header;
      for (final field in [
        header.vaultId,
        header.kdf.salt,
        header.passwordSlot.nonce,
        header.passwordSlot.cipherText,
        header.recoverySlot.nonce,
        header.recoverySlot.cipherText,
      ]) {
        expect(_contains(field, vaultKeyBytes), isFalse);
      }
    });

    test('istenen geçiş sayısı kullanılıyor', () async {
      final custom = await crypto.createVault(password, opsLimit: 4);
      addTearDown(custom.vaultKey.dispose);

      expect(custom.header.kdf.opsLimit, 4);
      expect(
        bytesOf(await crypto.unlockWithPassword(custom.header, password)),
        custom.vaultKey.extractBytes(),
      );
    });
  });

  group('parola ile açma', () {
    test('doğru parola kasa anahtarını veriyor', () async {
      expect(
        bytesOf(await crypto.unlockWithPassword(vault.header, password)),
        vaultKeyBytes,
      );
    });

    test('yanlış parola temiz hata veriyor', () async {
      for (final wrong in ['yanlış', '', '$password ', 'DOĞRU-PAROLA-IĞÜŞÖÇ']) {
        await expectLater(
          crypto.unlockWithPassword(vault.header, wrong),
          throwsWrongSecret(),
        );
      }
    });
  });

  group('kurtarma anahtarı ile açma', () {
    test('doğru anahtar aynı kasa anahtarını veriyor', () {
      expect(
        bytesOf(
          crypto.unlockWithRecoveryKey(vault.header, vault.recoveryKeyText),
        ),
        vaultKeyBytes,
      );
    });

    test('başka kasanın anahtarı reddediliyor', () async {
      final other = await crypto.createVault(password);
      addTearDown(other.vaultKey.dispose);

      expect(
        () => crypto.unlockWithRecoveryKey(vault.header, other.recoveryKeyText),
        throwsWrongSecret(),
      );
    });

    test('bozuk metin kriptoya ulaşmadan reddediliyor', () {
      expect(
        () => crypto.unlockWithRecoveryKey(vault.header, 'yanlis'),
        throwsA(isA<InvalidRecoveryKeyException>()),
      );
    });
  });

  group('parola değiştirme', () {
    late VaultHeader changed;

    setUpAll(() async {
      changed = await crypto.changePassword(
        vault.header,
        vault.vaultKey,
        otherPassword,
      );
    });

    test('yeni parola aynı kasa anahtarını veriyor', () async {
      expect(
        bytesOf(await crypto.unlockWithPassword(changed, otherPassword)),
        vaultKeyBytes,
      );
    });

    test('eski parola artık çalışmıyor', () async {
      await expectLater(
        crypto.unlockWithPassword(changed, password),
        throwsWrongSecret(),
      );
    });

    test('kurtarma anahtarı çalışmaya devam ediyor', () {
      expect(
        bytesOf(crypto.unlockWithRecoveryKey(changed, vault.recoveryKeyText)),
        vaultKeyBytes,
      );
    });

    test('tuz ve nonce yenileniyor, kimlik korunuyor', () {
      expect(changed.vaultId, vault.header.vaultId);
      expect(changed.kdf.salt, isNot(vault.header.kdf.salt));
      expect(
        changed.passwordSlot.nonce,
        isNot(vault.header.passwordSlot.nonce),
      );
    });

    test('yeni parolanın geçiş sayısı değiştirilebiliyor', () async {
      final raised = await crypto.changePassword(
        vault.header,
        vault.vaultKey,
        otherPassword,
        opsLimit: 5,
      );

      expect(raised.kdf.opsLimit, 5);
    });
  });

  group('değiştirilmiş üst bilgi açılmıyor', () {
    Future<void> expectPasswordRejected(VaultHeader header) => expectLater(
      crypto.unlockWithPassword(header, password),
      throwsWrongSecret(),
    );

    test('parola yuvası şifreli metni', () async {
      final slot = vault.header.passwordSlot;
      await expectPasswordRejected(
        copyHeader(
          passwordSlot: WrappedKey(
            nonce: slot.nonce,
            cipherText: flipBit(slot.cipherText),
          ),
        ),
      );
    });

    test('parola yuvası etiketi', () async {
      final slot = vault.header.passwordSlot;
      await expectPasswordRejected(
        copyHeader(
          passwordSlot: WrappedKey(
            nonce: slot.nonce,
            cipherText: flipBit(slot.cipherText, slot.cipherText.length - 1),
          ),
        ),
      );
    });

    test('parola yuvası nonce değeri', () async {
      final slot = vault.header.passwordSlot;
      await expectPasswordRejected(
        copyHeader(
          passwordSlot: WrappedKey(
            nonce: flipBit(slot.nonce),
            cipherText: slot.cipherText,
          ),
        ),
      );
    });

    test('kasa kimliği', () async {
      await expectPasswordRejected(
        copyHeader(vaultId: flipBit(vault.header.vaultId)),
      );
      expect(
        () => crypto.unlockWithRecoveryKey(
          copyHeader(vaultId: flipBit(vault.header.vaultId)),
          vault.recoveryKeyText,
        ),
        throwsWrongSecret(),
      );
    });

    test('Argon2id tuzu', () async {
      final kdf = vault.header.kdf;
      await expectPasswordRejected(
        copyHeader(
          kdf: KdfParams(
            opsLimit: kdf.opsLimit,
            memLimit: kdf.memLimit,
            salt: flipBit(kdf.salt),
          ),
        ),
      );
    });

    test('Argon2id parametreleri', () async {
      final kdf = vault.header.kdf;
      await expectPasswordRejected(
        copyHeader(
          kdf: KdfParams(
            opsLimit: kdf.opsLimit + 1,
            memLimit: kdf.memLimit,
            salt: kdf.salt,
          ),
        ),
      );
    });

    test('yuvalar birbirinin yerine konamıyor', () async {
      final header = vault.header;
      await expectPasswordRejected(
        copyHeader(passwordSlot: header.recoverySlot),
      );
      expect(
        () => crypto.unlockWithRecoveryKey(
          copyHeader(recoverySlot: header.passwordSlot),
          vault.recoveryKeyText,
        ),
        throwsWrongSecret(),
      );
    });
  });

  group('ek doğrulama verisi', () {
    test('alan sınırları kayarsa farklı sonuç üretiyor', () {
      expect(
        buildAssociatedData(['ab', 'c']),
        isNot(buildAssociatedData(['a', 'bc'])),
      );
    });

    test('bilinen bayt dizilimi üretiyor', () {
      expect(
        buildAssociatedData([
          'a',
          1,
          Uint8List.fromList([7, 8]),
        ]),
        [
          0, 0, 0, 1, 0x61, //
          0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 1, //
          0, 0, 0, 2, 7, 8, //
        ],
      );
    });

    test('desteklenmeyen tür reddediliyor', () {
      expect(() => buildAssociatedData([1.5]), throwsArgumentError);
    });
  });
}

bool _contains(Uint8List haystack, Uint8List needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var found = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        found = false;
        break;
      }
    }
    if (found) return true;
  }
  return false;
}
