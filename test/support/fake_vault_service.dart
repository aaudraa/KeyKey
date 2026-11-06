import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/platform/export_file_picker.dart';
import 'package:keykey/core/platform/qr_image_reader.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otp_clock.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/import/platform_aes_gcm.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/qr_scan_screen.dart';
import 'package:keykey/features/generator/data/wordlists.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:sodium/sodium_sumo.dart';

import '../core/storage/test_data.dart';
import 'vector_aes_gcm.dart';

/// Ekran testleri için anında yanıt veren kasa servisi. Argon2id çalıştırmaz.
class FakeVaultService implements VaultService {
  new(this.sodium);

  static const correctPassword = 'dogru-Ana-Parola-47';
  // Gerçek anahtar gibi 55 karakter; ekranlar uzunluğu denetliyor.
  static const recoveryKey =
      'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE-FFFFF-GGGGG-HHHHH-JJJJJ-KKKKK-MMMMM';

  /// Son grubu farklı; sahte servis bunu yazım hatası sayar.
  static const invalidRecoveryKey =
      'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE-FFFFF-GGGGG-HHHHH-JJJJJ-KKKKK-MMMMN';

  /// Doğru uzunlukta ama başka bir kasanın anahtarı.
  static const otherRecoveryKey =
      'ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ-ZZZZZ';

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
    // Ekran yazılanı biçimlendirir; gerçek çözücü gibi tire ve harf
    // farklarına bakılmaz.
    final symbols = RecoveryKeyCodec.symbolsOf(text);
    if (symbols == RecoveryKeyCodec.symbolsOf(invalidRecoveryKey)) {
      throw const InvalidRecoveryKeyException('Geçersiz.');
    }
    if (symbols != RecoveryKeyCodec.symbolsOf(recoveryKey)) {
      throw const WrongSecretException();
    }
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

  BiometricSupport biometricSupportValue = BiometricSupport.unavailable;
  bool biometricEnabled = false;

  /// Sonraki parmak izi denemesinin sonucu.
  BiometricOutcome<void> nextBiometric = const BiometricCancelled();
  int biometricPrompts = 0;

  @override
  Future<BiometricSupport> biometricSupport() async => biometricSupportValue;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<bool> isBiometricUsable() async =>
      biometricEnabled && biometricSupportValue == BiometricSupport.available;

  @override
  Future<BiometricOutcome<void>> enableBiometric(
    VaultSession session,
    BiometricTexts texts,
  ) async {
    biometricPrompts++;
    if (nextBiometric is BiometricSuccess) biometricEnabled = true;
    return nextBiometric;
  }

  @override
  Future<void> disableBiometric() async {
    biometricEnabled = false;
  }

  @override
  Future<BiometricOutcome<VaultSession>> unlockWithBiometric(
    VaultHeader header,
    BiometricTexts texts,
  ) async {
    biometricPrompts++;
    return switch (nextBiometric) {
      BiometricSuccess() => BiometricSuccess(newSession()),
      BiometricCancelled() => const BiometricCancelled(),
      BiometricLockedOut() => const BiometricLockedOut(),
      BiometricInvalidated() => const BiometricInvalidated(),
      BiometricFailed() => const BiometricFailed(),
    };
  }
}

/// Kopyalananları kaydeder. Gerçek panoyu cihaz testi sınar.
class RecordingClipboard implements SensitiveClipboard {
  final List<String> copied = [];

  @override
  Future<void> copy(String text) async => copied.add(text);
}

/// Bellekte çalışan kayıt deposu. Şifrelemeyi depo testleri sınar.
class FakeLoginRepository implements LoginRepository {
  new({List<LoginItem>? items, this.unreadableCount = 0}) : items = items ?? [];

  final List<LoginItem> items;
  final int unreadableCount;
  DateTime now = DateTime.utc(2026, 11, 5, 12);
  var _nextId = 1;

  static LoginItem item(
    LoginContent content, {
    int id = 0,
    DateTime? updatedAt,
  }) {
    final bytes = Uint8List(16)..[15] = id;
    return LoginItem(
      id: bytes,
      content: content,
      createdAt: DateTime.utc(2026),
      updatedAt: updatedAt ?? DateTime.utc(2026),
    );
  }

  @override
  Future<LoadedLogins> loadAll() async =>
      LoadedLogins(items: [...items], unreadableCount: unreadableCount);

  @override
  Future<LoginItem> add(LoginContent content) async {
    final created = LoginItem(
      id: Uint8List(16)
        ..[0] = 200
        ..[15] = _nextId++,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    items.add(created);
    return created;
  }

  @override
  Future<LoginItem> update(LoginItem item, LoginContent edited) =>
      _replace(item, item.content.applyEdit(edited, now));

  @override
  Future<LoginItem> updateMetadata(LoginItem item, LoginContent content) =>
      _replace(item, content);

  @override
  Future<void> deletePermanently(LoginItem item) async {
    items.removeWhere((other) => listEquals(other.id, item.id));
  }

  @override
  Future<List<LoginItem>> purgeExpiredTrash(List<LoginItem> items) async =>
      items;

  Future<LoginItem> _replace(LoginItem item, LoginContent content) async {
    final updated = LoginItem(
      id: item.id,
      content: content,
      createdAt: item.createdAt,
      updatedAt: now,
    );
    final index = items.indexWhere((other) => listEquals(other.id, item.id));
    items[index] = updated;
    return updated;
  }
}

/// Seçilen görselin sonucunu testin belirlediği gibi döndürür.
class FakeQrImageReader implements QrImageReader {
  QrImageResult next = const QrImageCancelled();
  int calls = 0;

  @override
  Future<QrImageResult> pickAndRead() async {
    calls++;
    return next;
  }
}

/// Bellekte duran ayarlar.
class FakeSettingsRepository implements SettingsRepository {
  new([this.settings = AppSettings.defaults]);

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async => this.settings = settings;
}

/// Seçilmiş gibi davranılan dışa aktarma dosyası.
class FakeExportFilePicker implements ExportFilePicker {
  ExportFileResult next = const ExportFileCancelled();
  int calls = 0;

  @override
  Future<ExportFileResult> pickAndRead() async {
    calls++;
    return next;
  }
}

/// Kamera yerine: test, [scan] ile okunmuş gibi metin verir.
class FakeQrCamera {
  late ValueChanged<String> _onText;
  late VoidCallback _onUnavailable;

  /// Kamera ekrana geldi mi.
  bool isShown = false;

  void scan(String text) => _onText(text);

  void fail() => _onUnavailable();

  Widget build({
    required ValueChanged<String> onText,
    required VoidCallback onUnavailable,
  }) {
    _onText = onText;
    _onUnavailable = onUnavailable;
    isShown = true;
    return const ColoredBox(color: Colors.black);
  }
}

/// Bellekte çalışan 2FA deposu. Şifrelemeyi depo testleri sınar.
class FakeOtpRepository implements OtpRepository {
  new({List<OtpItem>? items, this.unreadableCount = 0}) : items = items ?? [];

  final List<OtpItem> items;
  final int unreadableCount;
  DateTime now = DateTime.utc(2026, 11, 6, 12);
  var _nextId = 1;

  static OtpItem item(OtpContent content, {int id = 0}) => OtpItem(
    id: Uint8List(16)
      ..[0] = 100
      ..[15] = id,
    content: content,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  @override
  Future<LoadedOtps> loadAll() async =>
      LoadedOtps(items: [...items], unreadableCount: unreadableCount);

  @override
  Future<OtpItem> add(OtpContent content) async {
    final created = OtpItem(
      id: Uint8List(16)
        ..[0] = 201
        ..[15] = _nextId++,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    items.add(created);
    return created;
  }

  @override
  Future<OtpItem> update(OtpItem item, OtpContent content) async {
    final updated = OtpItem(
      id: item.id,
      content: content,
      createdAt: item.createdAt,
      updatedAt: now,
    );
    final index = items.indexWhere((other) => listEquals(other.id, item.id));
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePermanently(OtpItem item) async {
    items.removeWhere((other) => listEquals(other.id, item.id));
  }

  @override
  Future<List<OtpItem>> purgeExpiredTrash(List<OtpItem> items) async => items;
}

// Büyük varlık dosyalarını Flutter ayrı isolate'te okur, sahte saatli
// testlerde bu tamamlanmaz. Testler listeleri doğrudan dosyadan alır.
final List<String> _effWords = Wordlists.parseEff(
  File(Wordlists.effPath).readAsStringSync(),
);
final Set<String> _commonPasswords = Wordlists.parseCommon(
  File(Wordlists.commonPath).readAsStringSync(),
);

/// Uygulamayı verilen kasa durumuyla açar.
Future<void> pumpKeyKey(
  WidgetTester tester, {
  required VaultStatus status,
  required FakeVaultService service,
  FakeLoginRepository? logins,
  FakeOtpRepository? otps,
  DateTime Function()? clock,
  FakeQrImageReader? qrImages,
  FakeQrCamera? camera,
  FakeExportFilePicker? files,
  FakeSettingsRepository? settings,
  RecordingClipboard? clipboard,
  Locale locale = const Locale('tr'),
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final repository = logins ?? FakeLoginRepository();
  final otpRepository = otps ?? FakeOtpRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultServiceProvider.overrideWithValue(service),
        initialVaultStatusProvider.overrideWithValue(status),
        loginRepositoryFactoryProvider.overrideWithValue((_) => repository),
        otpRepositoryFactoryProvider.overrideWithValue((_) => otpRepository),
        settingsRepositoryFactoryProvider.overrideWithValue(
          (_) => settings ?? FakeSettingsRepository(),
        ),
        if (clock != null) otpClockProvider.overrideWithValue(clock),
        qrImageReaderProvider.overrideWithValue(
          qrImages ?? FakeQrImageReader(),
        ),
        qrCameraProvider.overrideWithValue((camera ?? FakeQrCamera()).build),
        exportFilePickerProvider.overrideWithValue(
          files ?? FakeExportFilePicker(),
        ),
        aesGcmProvider.overrideWithValue(VectorAesGcm()),
        randomSourceProvider.overrideWithValue(
          SodiumRandomSource(service.sodium),
        ),
        sensitiveClipboardProvider.overrideWithValue(
          clipboard ?? RecordingClipboard(),
        ),
        effWordlistProvider.overrideWith((ref) async => _effWords),
        commonPasswordsProvider.overrideWith((ref) async => _commonPasswords),
      ],
      child: const KeyKeyApp(),
    ),
  );
  await tester.pumpAndSettle();
}
