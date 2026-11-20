import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/network/webdav_client.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/core/platform/backup_folders.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/platform/export_file_picker.dart';
import 'package:keykey/core/platform/pigeon_biometric_bridge.dart';
import 'package:keykey/core/platform/qr_image_reader.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/platform/web_links.dart';
import 'package:keykey/core/storage/storage_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/import/platform_aes_gcm.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/backup/application/auto_backup_controller.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/backup/data/auto_backup_device.dart';
import 'package:keykey/features/generator/data/wordlists.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/onboarding/application/terms_controller.dart';
import 'package:keykey/features/onboarding/data/terms_acceptance.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/application/theme_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/settings/data/theme_preference.dart';
import 'package:keykey/features/sync/application/sync_controller.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// Uygulamayı başlatır: libsodium'u yükler, kasa dosyasını açar ve başlangıç
/// durumunu belirler.
///
/// Dosya okunamıyorsa kullanıcıya hata ekranı gösterilir ve dosyaya dokunulmaz.
Future<List<Override>> bootstrap() async {
  final sodium = await SodiumSumoInit.init();
  final directory = await getApplicationSupportDirectory();

  // Tema kasadan bağımsız: kasa dosyası açılamasa da seçilen temayla açılır.
  final themeStore = FileThemePreferenceStore(File('${directory.path}/theme'));
  final theme = [
    themePreferenceStoreProvider.overrideWithValue(themeStore),
    initialThemeModeProvider.overrideWithValue(await themeStore.read()),
  ];

  // Kullanım koşullarının kabulü de kasadan bağımsız: kasa kurulmadan ve
  // kilit açılmadan önce sorulur.
  final termsStore = FileTermsAcceptanceStore(File('${directory.path}/terms'));
  final terms = [
    termsAcceptanceStoreProvider.overrideWithValue(termsStore),
    initialTermsAcceptedProvider.overrideWithValue(await termsStore.accepted()),
  ];

  final VaultDatabase database;
  try {
    database = VaultDatabase.openFile(File('${directory.path}/keykey.db'));
  } on UnsupportedSchemaException {
    return [
      ...theme,
      ...terms,
      initialVaultStatusProvider.overrideWithValue(const VaultUnavailable()),
    ];
  }

  // Otomatik yedek dosyalarının adındaki cihaz kimliği: kasanın dışında,
  // yedekle taşınmaz; aynı klasörü kullanan iki kurulumu ayırır.
  final autoBackupDevice = await readOrCreateAutoBackupDevice(
    File('${directory.path}/auto_backup_device'),
    random: sodium.randombytes.buf,
  );

  final store = VaultStore(database);
  final service = VaultService(
    sodium: sodium,
    store: store,
    biometric: PigeonBiometricBridge(),
  );
  return [
    ...theme,
    ...terms,
    randomSourceProvider.overrideWithValue(SodiumRandomSource(sodium)),
    sensitiveClipboardProvider.overrideWithValue(PigeonSensitiveClipboard()),
    qrImageReaderProvider.overrideWithValue(ZxingQrImageReader()),
    exportFilePickerProvider.overrideWithValue(FileSelectorExportPicker()),
    documentFilesProvider.overrideWithValue(PigeonDocumentFiles()),
    backupFoldersProvider.overrideWithValue(PigeonBackupFolders()),
    autoBackupDeviceProvider.overrideWithValue(autoBackupDevice),
    appPackagesProvider.overrideWithValue(PigeonAppPackages()),
    webLinksProvider.overrideWithValue(PigeonWebLinks()),
    backupServiceProvider.overrideWithValue(
      BackupService(sodium: sodium, store: store),
    ),
    restoreServiceProvider.overrideWithValue(
      RestoreService(sodium: sodium, store: store),
    ),
    syncServiceProvider.overrideWithValue(
      SyncService(
        store: store,
        codec: BackupCodec(sodium),
        sodium: sodium,
        transport: (settings) => WebDavClient(
          folder: settings.folder,
          username: settings.username,
          password: settings.appPassword,
        ),
        device: autoBackupDevice,
        deviceName: PigeonAppPackages().deviceModel,
        now: () => DateTime.now().toUtc(),
      ),
    ),
    aesGcmProvider.overrideWithValue(PlatformAesGcm()),
    vaultServiceProvider.overrideWithValue(service),
    loginRepositoryFactoryProvider.overrideWithValue(
      (session) =>
          LoginRepository(store: store, session: session, sodium: sodium),
    ),
    cardRepositoryFactoryProvider.overrideWithValue(
      (session) =>
          cardRepository(store: store, session: session, sodium: sodium),
    ),
    noteRepositoryFactoryProvider.overrideWithValue(
      (session) =>
          noteRepository(store: store, session: session, sodium: sodium),
    ),
    settingsRepositoryFactoryProvider.overrideWithValue(
      (session) => SettingsRepository(store: store, session: session),
    ),
    otpRepositoryFactoryProvider.overrideWithValue(
      (session) =>
          OtpRepository(store: store, session: session, sodium: sodium),
    ),
    initialVaultStatusProvider.overrideWithValue(await _loadStatus(service)),
  ];
}

Future<VaultStatus> _loadStatus(VaultService service) async {
  try {
    final header = await service.readHeader();
    return header == null ? const VaultNotSetUp() : VaultLocked(header);
  } on InvalidVaultHeaderException {
    return const VaultUnavailable();
  }
}
