import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../core/storage/test_data.dart';

/// Ekran testleri için anında yanıt veren kasa servisi. Argon2id çalıştırmaz.
class FakeVaultService implements VaultService {
  new(this.sodium);

  static const correctPassword = 'dogru-Ana-Parola-47';
  static const recoveryKey = 'AAAAA-BBBBB-CCCCC';
  static const invalidRecoveryKey = 'GECERSIZ';

  final SodiumSumo sodium;
  final VaultHeader header = sampleHeader();

  /// Sonraki denemede bildirilecek bekleme.
  Duration waitAfterReject = Duration.zero;

  /// Şu an süren bekleme.
  Duration currentWait = Duration.zero;

  int prepareCount = 0;
  String? changedPassword;

  VaultSession newSession() {
    final key = sodium.secureRandom(32);
    return VaultSession(
      header: header,
      vaultKey: key,
      records: RecordCipher(sodium, key, header.vaultId),
    );
  }

  void _checkRecovery(String text) {
    if (text == invalidRecoveryKey) {
      throw const InvalidRecoveryKeyException('Geçersiz.');
    }
    if (text != recoveryKey) throw const WrongSecretException();
  }

  @override
  Future<VaultHeader?> readHeader() async => header;

  @override
  Future<PendingVault> prepareVault(String password) async {
    prepareCount++;
    return PendingVault(
      CreatedVault(
        header: header,
        vaultKey: sodium.secureRandom(32),
        recoveryKeyText: recoveryKey,
      ),
    );
  }

  @override
  Future<VaultSession> confirmRecoveryKey(
    PendingVault pending,
    String typedRecoveryKey,
  ) async {
    _checkRecovery(typedRecoveryKey);
    return VaultSession(
      header: header,
      vaultKey: pending.created.vaultKey,
      records: RecordCipher(sodium, pending.created.vaultKey, header.vaultId),
    );
  }

  @override
  Future<Duration> remainingWait() async => currentWait;

  @override
  Future<UnlockOutcome> unlockWithPassword(
    VaultHeader header,
    String password,
  ) async {
    if (currentWait > Duration.zero) {
      return UnlockOutcome(PasswordMustWait(currentWait));
    }
    if (password == correctPassword) {
      return UnlockOutcome(const PasswordAccepted(), newSession());
    }
    return UnlockOutcome(PasswordRejected(waitAfterReject));
  }

  @override
  VaultSession unlockWithRecoveryKey(VaultHeader header, String text) {
    _checkRecovery(text);
    return newSession();
  }

  @override
  Future<PasswordAttempt> changePassword(
    VaultSession session, {
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword != correctPassword) {
      return PasswordRejected(waitAfterReject);
    }
    changedPassword = newPassword;
    return const PasswordAccepted();
  }

  @override
  Future<void> setNewPassword(VaultSession session, String newPassword) async {
    changedPassword = newPassword;
  }
}

/// Uygulamayı verilen kasa durumuyla açar.
Future<void> pumpKeyKey(
  WidgetTester tester, {
  required VaultStatus status,
  required VaultService service,
  Locale locale = const Locale('tr'),
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultServiceProvider.overrideWithValue(service),
        initialVaultStatusProvider.overrideWithValue(status),
      ],
      child: const KeyKeyApp(),
    ),
  );
  await tester.pumpAndSettle();
}
