import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/core/platform/backup_folders.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/platform/export_file_picker.dart';
import 'package:keykey/core/platform/qr_image_reader.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/platform/web_links.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otp_clock.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/import/platform_aes_gcm.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/qr_scan_screen.dart';
import 'package:keykey/features/autofill/application/autofill_setup.dart';
import 'package:keykey/features/backup/application/auto_backup_controller.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/generator/data/wordlists.dart';
import 'package:keykey/features/lock/application/lock_clock.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/record_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
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

  /// Verilirse parola değişimi bu tamamlanana kadar sürer.
  Completer<void>? changeGate;

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
    if (currentWait > Duration.zero) return PasswordMustWait(currentWait);
    if (currentPassword != correctPassword) {
      return PasswordRejected(waitAfterReject);
    }
    await changeGate?.future;
    changedPassword = newPassword;
    return const PasswordAccepted();
  }

  @override
  Future<void> setNewPassword(VaultSession session, String newPassword) async {
    changedPassword = newPassword;
  }

  /// Yeni kurtarma anahtarı olarak gösterilen metin (55 karakter).
  static const newRecoveryKey =
      'NNNNN-PPPPP-QQQQQ-RRRRR-SSSSS-TTTTT-VVVVV-WWWWW-XXXXX-YYYYY-ZZZZZ';

  /// Doğrulanıp yazılan yeni kurtarma anahtarı.
  String? confirmedRecoveryKey;

  @override
  Future<(PasswordAttempt, PendingRecoveryKey?)> prepareNewRecoveryKey(
    VaultSession session,
    String currentPassword,
  ) async {
    if (currentWait > Duration.zero) {
      return (PasswordMustWait(currentWait), null);
    }
    if (currentPassword != correctPassword) {
      return (PasswordRejected(waitAfterReject), null);
    }
    await changeGate?.future;
    return (
      const PasswordAccepted(),
      PendingRecoveryKey(
        vaultId: header.vaultId,
        renewed: NewRecoveryKey(
          recoverySlot: header.recoverySlot,
          recoveryKeyText: newRecoveryKey,
        ),
      ),
    );
  }

  @override
  Future<void> confirmNewRecoveryKey(
    VaultSession session,
    PendingRecoveryKey pending,
    String typedRecoveryKey,
  ) async {
    await changeGate?.future;
    final symbols = RecoveryKeyCodec.symbolsOf(typedRecoveryKey);
    if (symbols.length != RecoveryKeyCodec.textLength) {
      throw const InvalidRecoveryKeyException('Geçersiz.');
    }
    if (symbols != RecoveryKeyCodec.symbolsOf(pending.recoveryKeyText)) {
      throw const WrongSecretException();
    }
    confirmedRecoveryKey = pending.recoveryKeyText;
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
  VaultSession openRestoredSession(VaultHeader header, SecureKey vaultKey) =>
      VaultSession(
        header: header,
        vaultKey: vaultKey,
        records: RecordCipher(sodium, vaultKey, header.vaultId),
      );

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

/// 1×1 saydam PNG; sahte uygulama simgesi.
final Uint8List fakeIconPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Açılan sayfaları kaydeder; [result] `false` ise tarayıcı yok gibi davranır.
class RecordingWebLinks implements WebLinks {
  final opened = <Uri>[];
  bool result = true;

  @override
  Future<bool> open(Uri page) async {
    opened.add(page);
    return result;
  }
}

/// Verilen paketlerin simgesini döndürür, diğerlerinde `null`.
class FakeAppPackages implements AppPackages {
  new({Set<String> installed = const {}, this.version = '1.0.0'})
    : installed = {...installed};

  final Set<String> installed;
  final String version;

  @override
  Future<Uint8List?> appIcon(String packageName) async =>
      installed.contains(packageName) ? fakeIconPng : null;

  @override
  Future<String> versionName() async => version;

  @override
  Future<String> deviceModel() async => 'Test Telefonu';
}

/// Kopyalananları kaydeder. Gerçek panoyu cihaz testi sınar.
class RecordingClipboard implements SensitiveClipboard {
  final List<String> copied = [];

  @override
  Future<void> copy(String text) async => copied.add(text);
}

/// Bellekte duran kart ya da not deposu.
class FakeRecordRepository<C extends VaultItemContent<C>>
    implements VaultRecordRepository<C> {
  new({List<VaultRecord<C>>? items, this.unreadableCount = 0})
    : items = items ?? [];

  final List<VaultRecord<C>> items;
  final int unreadableCount;
  DateTime now = DateTime.utc(2026, 11, 5, 12);
  var _nextId = 1;

  @override
  String get type => C == CardContent
      ? VaultRecordRepository.cardType
      : VaultRecordRepository.noteType;

  static VaultRecord<C> item<C>(C content, {int id = 0, DateTime? updatedAt}) {
    final bytes = Uint8List(16)
      ..[0] = 100
      ..[15] = id;
    return VaultRecord(
      id: bytes,
      content: content,
      createdAt: DateTime.utc(2026),
      updatedAt: updatedAt ?? DateTime.utc(2026),
    );
  }

  @override
  Future<LoadedRecords<C>> loadAll() async =>
      LoadedRecords(items: [...items], unreadableCount: unreadableCount);

  @override
  Future<VaultRecord<C>> add(C content) async {
    final created = VaultRecord(
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
  Future<VaultRecord<C>> update(VaultRecord<C> item, C content) async {
    final updated = VaultRecord(
      id: item.id,
      content: content,
      createdAt: item.createdAt,
      updatedAt: now,
    );
    final index = items.indexWhere((other) => listEquals(other.id, item.id));
    if (index >= 0) items[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePermanently(VaultRecord<C> item) async {
    items.removeWhere((other) => listEquals(other.id, item.id));
  }

  @override
  Future<List<VaultRecord<C>>> purgeExpiredTrash(
    List<VaultRecord<C>> items,
  ) async => items;
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

/// Otomatik doldurma kurulumunun sahtesi; açılan ayarları kaydeder.
class FakeAutofillSetup implements AutofillSetupBridge {
  new([this.state = const AutofillSetupState(supported: true, enabled: false)]);

  AutofillSetupState state;
  bool canOpen = true;
  final List<String> opened = [];

  @override
  Future<AutofillSetupState> status() async => state;

  @override
  Future<bool> openAutofillSettings() async {
    opened.add('autofill');
    return canOpen;
  }

  @override
  Future<bool> openChromeAutofillSettings() async {
    opened.add('chrome');
    return canOpen;
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

/// Belge seçicinin yerine: kaydedilen baytları tutar, açmada [nextOpen] döner.
class FakeDocumentFiles implements DocumentFiles {
  DocumentSaveResult nextSave = DocumentSaveResult.saved;
  DocumentOpenResult nextOpen = const DocumentOpenCancelled();

  /// Son kaydedilen dosyanın adı ve baytlarının kopyası.
  String? savedName;
  String? savedMimeType;
  Uint8List? savedBytes;
  int saves = 0;
  int opens = 0;

  /// Seçici açıkken arka plan kilidi ertelendi mi.
  bool? gateWasActive;
  bool Function()? readGate;

  @override
  Future<DocumentSaveResult> save({
    required String suggestedName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    saves++;
    gateWasActive = readGate?.call();
    savedName = suggestedName;
    savedMimeType = mimeType;
    savedBytes = Uint8List.fromList(bytes);
    bytes.fillRange(0, bytes.length, 0);
    return nextSave;
  }

  @override
  Future<DocumentOpenResult> open({
    required List<String> mimeTypes,
    required int maxBytes,
  }) async {
    opens++;
    gateWasActive = readGate?.call();
    return nextOpen;
  }
}

/// Otomatik yedek klasörünün yerine: klasörleri bellekte tutar.
class FakeBackupFolders implements BackupFolders {
  /// Klasör adresi → dosya adı → içerik.
  final Map<String, Map<String, Uint8List>> files = {};

  /// Kalıcı izni olan klasörler.
  final Set<String> granted = {};

  /// Seçicinin bir sonraki sonucu. Seçilen klasöre izin verilir.
  FolderPick nextPick = const FolderPickCancelled();

  bool failWrites = false;
  int picks = 0;
  int writes = 0;
  final List<String> released = [];

  /// Seçici açıkken arka plan kilidi ertelendi mi.
  bool? gateWasActive;
  bool Function()? readGate;

  @override
  Future<FolderPick> pick() async {
    picks++;
    gateWasActive = readGate?.call();
    final pick = nextPick;
    if (pick is FolderPicked) {
      granted.add(pick.uri);
      files.putIfAbsent(pick.uri, () => {});
    }
    return pick;
  }

  @override
  Future<bool> hasAccess(String uri) async => granted.contains(uri);

  @override
  Future<List<String>?> list(String uri) async =>
      granted.contains(uri) ? files[uri]?.keys.toList() : null;

  @override
  Future<bool> write(String uri, String name, Uint8List bytes) async {
    writes++;
    try {
      if (failWrites || !granted.contains(uri)) return false;
      final folder = files[uri] ??= {};
      // Kotlin tarafı, sağlayıcı adı değiştirirse ("… (1)") yazmayı geri alır.
      if (folder.containsKey(name)) return false;
      folder[name] = Uint8List.fromList(bytes);
      return true;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  @override
  Future<int> delete(String uri, List<String> names) async {
    final folder = files[uri];
    if (folder == null || !granted.contains(uri)) return 0;
    return names.where((name) => folder.remove(name) != null).length;
  }

  @override
  Future<void> release(String uri) async {
    released.add(uri);
    granted.remove(uri);
  }
}

/// Yedek servisinin yerine: kasa yerine sabit baytlar üretir.
class FakeBackupService implements BackupService {
  Uint8List bytes = Uint8List.fromList([1, 2, 3]);
  int creates = 0;

  /// Kayıtların en son değiştiği an; `null` boş kasa demek.
  DateTime? latest;

  /// `true` ise yedek boyut sınırını aşıyormuş gibi davranır.
  bool tooLarge = false;

  @override
  Future<DateTime?> latestChange() async => latest;

  @override
  Future<Uint8List> create(VaultSession session, DateTime now) async {
    if (session.isDisposed) throw const VaultLockedException();
    if (tooLarge) throw const BackupTooLargeException();
    creates++;
    return Uint8List.fromList(bytes);
  }
}

/// Geri yükleme servisinin yerine. Dosya yapısını gerçek okuyucu denetler;
/// açma, sahte servisin parolası veya kurtarma anahtarıyla başarılı olur.
class FakeRestoreService implements RestoreService {
  new(this.sodium);

  static const password = 'yedek-Parolasi-55';

  final SodiumSumo sodium;
  int replaces = 0;
  int merges = 0;
  bool corrupted = false;

  /// `true` ise yedek açılırken daha yeni bir sürümün içeriği gibi davranır.
  bool newer = false;
  int cardCount = 0;
  int noteCount = 0;

  /// Birleştirme sırasında kasaya yazılıyormuş gibi çağrılır.
  void Function()? onMerge;
  MergeCounts mergeResult = const MergeCounts(added: 2, updated: 1, kept: 4);

  /// Gerçek biçimde, kayıtsız bir yedek dosyası.
  Future<Uint8List> backupBytes(VaultHeader header) async {
    final key = sodium.secureRandom(32);
    try {
      return await BackupCodec(sodium).encode(
        header: header,
        vaultKey: key,
        records: const [],
        createdAt: DateTime.utc(2026, 11, 1, 9),
      );
    } finally {
      key.dispose();
    }
  }

  @override
  BackupFile parse(Uint8List bytes) => BackupCodec(sodium).parse(bytes);

  @override
  Future<OpenedBackup> openWithPassword(BackupFile file, String text) async {
    if (text != password) throw const WrongSecretException();
    return _opened(file);
  }

  @override
  Future<OpenedBackup> openWithRecoveryKey(BackupFile file, String text) async {
    if (RecoveryKeyCodec.symbolsOf(text) !=
        RecoveryKeyCodec.symbolsOf(FakeVaultService.recoveryKey)) {
      throw const WrongSecretException();
    }
    return _opened(file);
  }

  OpenedBackup _opened(BackupFile file) {
    if (corrupted) throw const CorruptedDataException();
    if (newer) throw const NewerBackupException('Daha yeni içerik.');
    return OpenedBackup.forTesting(
      header: file.header,
      vaultKey: sodium.secureRandom(32),
      createdAt: DateTime.utc(2026, 11, 1, 9),
      loginCount: 3,
      otpCount: 2,
      cardCount: cardCount,
      noteCount: noteCount,
    );
  }

  /// Son değiştirmede verilen, bu cihazın otomatik yedek klasörü.
  AutoBackupFolder? replacedFolder;

  @override
  Future<void> replace(
    OpenedBackup backup, {
    AutoBackupFolder? autoBackupFolder,
  }) async {
    replaces++;
    replacedFolder = autoBackupFolder;
  }

  @override
  Future<MergeCounts> merge(OpenedBackup backup, VaultSession session) async {
    if (session.isDisposed) throw const VaultLockedException();
    merges++;
    onMerge?.call();
    return mergeResult;
  }
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
  static const Key key = ValueKey('fake-qr-camera');

  late ValueChanged<String> _onText;
  late VoidCallback _onUnavailable;
  late ValueChanged<QrTorch?> _onTorch;

  /// Kamera ekrana geldi mi.
  bool isShown = false;

  /// Fener açık mı.
  bool torchOn = false;

  void scan(String text) => _onText(text);

  void fail() => _onUnavailable();

  /// Kamera feneri olduğunu bildirir; [fails] ise fener açılmaya çalışılınca
  /// hata verir.
  void offerTorch({bool fails = false}) => _onTorch(() async {
    if (fails) throw StateError('fener yok');
    return torchOn = !torchOn;
  });

  Widget build({
    required ValueChanged<String> onText,
    required VoidCallback onUnavailable,
    required ValueChanged<QrTorch?> onTorch,
  }) {
    _onText = onText;
    _onUnavailable = onUnavailable;
    _onTorch = onTorch;
    isShown = true;
    return const ColoredBox(key: key, color: Colors.black);
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

/// Kasa yokken açılışta gelen tanıtımı atlayıp kurulum ekranına geçer.
Future<void> skipIntro(WidgetTester tester) async {
  await tester.tap(find.text('Atla'));
  await tester.pumpAndSettle();
}

/// Arka plan kilidinin saatleri; testler ikisini ayrı ayrı ilerletir.
class FakeLockClock implements LockClock {
  DateTime _wall = DateTime.utc(2026, 11, 20, 12);
  Duration _elapsed = Duration.zero;

  @override
  DateTime now() => _wall;

  @override
  Duration elapsed() => _elapsed;

  /// Tekdüze saati [monotonic] kadar, duvar saatini [wall] (verilmezse
  /// aynı) kadar ilerletir.
  void advance(Duration monotonic, {Duration? wall}) {
    _elapsed += monotonic;
    _wall = _wall.add(wall ?? monotonic);
  }
}

/// Uygulamayı verilen kasa durumuyla açar.
Future<void> pumpKeyKey(
  WidgetTester tester, {
  required VaultStatus status,
  required FakeVaultService service,
  FakeLoginRepository? logins,
  FakeOtpRepository? otps,
  FakeRecordRepository<CardContent>? cards,
  FakeRecordRepository<NoteContent>? notes,
  DateTime Function()? clock,
  FakeQrImageReader? qrImages,
  FakeQrCamera? camera,
  FakeExportFilePicker? files,
  FakeSettingsRepository? settings,
  RecordingClipboard? clipboard,
  FakeAutofillSetup? autofillSetup,
  FakeDocumentFiles? documents,
  FakeBackupFolders? folders,
  FakeBackupService? backups,
  FakeRestoreService? restores,
  AppPackages? packages,
  Locale locale = const Locale('tr'),
  bool settle = true,
  bool ambient = false,
  List<Override> extraOverrides = const [],
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final repository = logins ?? FakeLoginRepository();
  final otpRepository = otps ?? FakeOtpRepository();
  final cardRepository = cards ?? FakeRecordRepository<CardContent>();
  final noteRepository = notes ?? FakeRecordRepository<NoteContent>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ambientMotionProvider.overrideWithValue(ambient),
        vaultServiceProvider.overrideWithValue(service),
        initialVaultStatusProvider.overrideWithValue(status),
        loginRepositoryFactoryProvider.overrideWithValue((_) => repository),
        otpRepositoryFactoryProvider.overrideWithValue((_) => otpRepository),
        cardRepositoryFactoryProvider.overrideWithValue((_) => cardRepository),
        noteRepositoryFactoryProvider.overrideWithValue((_) => noteRepository),
        settingsRepositoryFactoryProvider.overrideWithValue(
          (_) => settings ?? FakeSettingsRepository(),
        ),
        if (clock != null) otpClockProvider.overrideWithValue(clock),
        if (clock != null) backupClockProvider.overrideWithValue(clock),
        documentFilesProvider.overrideWithValue(
          documents ?? FakeDocumentFiles(),
        ),
        backupFoldersProvider.overrideWithValue(folders ?? FakeBackupFolders()),
        autoBackupDeviceProvider.overrideWithValue('a1b2c3'),
        backupServiceProvider.overrideWithValue(backups ?? FakeBackupService()),
        restoreServiceProvider.overrideWithValue(
          restores ?? FakeRestoreService(service.sodium),
        ),
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
        autofillSetupBridgeProvider.overrideWithValue(
          autofillSetup ?? FakeAutofillSetup(),
        ),
        appPackagesProvider.overrideWithValue(packages ?? FakeAppPackages()),
        effWordlistProvider.overrideWith((ref) async => _effWords),
        commonPasswordsProvider.overrideWith((ref) async => _commonPasswords),
        ...extraOverrides,
      ],
      child: const KeyKeyApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
