# Otomatik yedek uygulama planı

> **Uygulayan için:** görevler sırayla, satır içi yürütülür (superpowers:executing-plans). Adımlar `- [ ]` kutularıyla izlenir.

**Amaç:** Kasa açıkken kayıtlar değişince, kullanıcının seçtiği klasöre elle yedekle aynı biçimde şifreli bir yedek yazmak; eski otomatik yedekleri budamak.

**Mimari:** Kotlin tarafında yeni bir Pigeon API'si (`BackupFolderApi`) klasör seçer, kalıcı izni tutar, dosya yazar/listeler/siler. Dart tarafında saf bir ad ve budama kuralı (`AutoBackupFiles`), klasörü taşıyan ayar kaydı sürüm 5 ve tetikleri yöneten bir Riverpod denetleyicisi (`AutoBackupController`) var. Arayüz ayarlarda bir satır ve yedek kartında bir durum satırı ekler.

**Teknoloji:** Flutter/Dart, Riverpod 3, Pigeon 30, Kotlin, Android Storage Access Framework (`DocumentsContract`).

**Tasarım:** [otomatik-yedek.md](otomatik-yedek.md)

## Genel kısıtlar

- Yeni izin yok: `INTERNET` ve depolama izni eklenmez; `check-release-apk.sh` geçmeli.
- Yeni kütüphane yok; Kotlin'de `androidx.documentfile` değil `DocumentsContract`.
- Yedek biçimi ve kripto değişmez; baytlar `BackupService.create` ile üretilir.
- Otomatik yedek dosya adı: `<önek>-YYYY-AA-GG-SSddss.keykey`, yerel saatle; önek Türkçede `keykey-otomatik`, diğer dillerde `keykey-auto`.
- Budama: her günün en yeni dosyası, en yeni 14 gün. Yalnızca adı kalıba tam uyan dosyalar silinir.
- Bekleme 5 saniye. İkisi de kodda sabit.
- Pigeon tek girdi dosyası (`pigeons/platform_api.dart`); üretimden sonra `dart format lib/core/platform/platform_api.g.dart`.
- Yazılan baytlar her yolda sıfırlanır (Dart ve Kotlin).
- Metinler Türkçe ve İngilizce ARB'de; İngilizce ARB'de `@anahtar` açıklaması.
- Kontroller: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`.

## Gözden geçirmede dikkat

1. **Elle yedek ya da yabancı dosya budanmamalı:** `keykey-yedek-2026-11-18.keykey`, `keykey-otomatik-2026-11-18-1530.keykey` (eksik saniye), `keykey-otomatik-2026-13-01-000000.keykey` (geçersiz ay), `keykey-otomatik-2026-11-18-153012.keykey.bak`, `keykey-otomatik-2026-11-18-153012 (1).keykey` silinmez. Test: Görev 2.
2. **Yazma başarısızken eski yedekler silinmemeli:** `write` `false` dönerse `list`/`delete` hiç çağrılmaz, son yedek zamanı ilerlemez. Test: Görev 4.
3. **Başka telefondan gelen klasör adresi:** `hasAccess` `false` ise yedek üretilmez, durum `noAccess` olur ve kullanıcı klasörü yeniden seçebilir. Test: Görev 4 ve 5.
4. **Kasa yazarken kilitlenirse:** süren iş çökmeden biter; `recordBackup`'ın `VaultLockedException`'ı yutulur, durum sıfırlanır, bekleyen zamanlayıcı iptal olur. Test: Görev 4.
5. **Ayar kaydı sürüm 5 bozuksa** (klasör alanı sayı, boş adres, `content://` ile başlamıyor, fazla alan) kayıt okunamaz sayılır (`requireAuth`); sürüm 1–4 aynen okunur. Test: Görev 3.

---

### Görev 1: Klasör köprüsü (Kotlin + Pigeon + Dart sarmalayıcı)

**Dosyalar:**
- Değiştir: `pigeons/platform_api.dart` (yeni `FolderPickStatus`, `FolderPickResult`, `BackupFolderApi`)
- Yeniden üret: `lib/core/platform/platform_api.g.dart`, `android/app/src/main/kotlin/io/github/aaudraa/keykey/PlatformApi.g.kt`
- Oluştur: `android/app/src/main/kotlin/io/github/aaudraa/keykey/BackupFolders.kt`
- Değiştir: `android/app/src/main/kotlin/io/github/aaudraa/keykey/MainActivity.kt` (`BackupFolderApi.setUp(messenger, BackupFolders(this))`)
- Oluştur: `lib/core/platform/backup_folders.dart`
- Değiştir: `lib/app/bootstrap.dart` (`backupFoldersProvider` → `PigeonBackupFolders()`)
- Değiştir: `test/support/fake_vault_service.dart` (`FakeBackupFolders`, `pumpKeyKey(folders:)`)
- Test: `test/core/platform/backup_folders_test.dart`

**Arayüzler:**
- Üretir (Pigeon):
  ```dart
  enum FolderPickStatus { done, cancelled, failed }
  class FolderPickResult { FolderPickStatus status; String? uri; String? name; }
  @HostApi() abstract class BackupFolderApi {
    @async FolderPickResult pick();              // ACTION_OPEN_DOCUMENT_TREE + kalıcı okuma/yazma izni
    bool hasAccess(String folderUri);            // persistedUriPermissions'ta okuma ve yazma var mı
    @async List<String>? list(String folderUri); // çocukların görünen adları; erişim yoksa null
    @async bool write(String folderUri, String name, String mimeType, Uint8List bytes);
    @async int delete(String folderUri, List<String> names); // silinen sayısı
    void release(String folderUri);              // releasePersistableUriPermission; hata yutulur
  }
  ```
- Üretir (Dart):
  ```dart
  sealed class FolderPick; final class FolderPicked(String uri, String name); FolderPickCancelled; FolderPickFailed
  abstract interface class BackupFolders {
    Future<FolderPick> pick();
    Future<bool> hasAccess(String uri);
    Future<List<String>?> list(String uri);
    Future<bool> write(String uri, String name, Uint8List bytes); // bytes işi bitince sıfırlanır
    Future<int> delete(String uri, List<String> names);
    Future<void> release(String uri);
  }
  final class PigeonBackupFolders implements BackupFolders
  final backupFoldersProvider = Provider<BackupFolders>((ref) => throw UnimplementedError(...));
  ```

- [ ] **Adım 1: Başarısız test.** `backup_folders_test.dart`: sahte `BackupFolderApi` ile `PigeonBackupFolders`.
  - `pick` sonucu `done`+uri+name → `FolderPicked`; `done` ama uri `null` → `FolderPickFailed`; `cancelled` → `FolderPickCancelled`.
  - `write` çağrısından sonra verilen `bytes` tamamen sıfır; mime türü `BackupService.mimeType`.
  - `write` istisna atarsa (`PlatformException`) `false` döner ve baytlar yine sıfır.
- [ ] **Adım 2:** `flutter test test/core/platform/backup_folders_test.dart` → derleme hatasıyla FAIL.
- [ ] **Adım 3:** Pigeon tanımı, `dart run pigeon --input pigeons/platform_api.dart`, `dart format lib/core/platform/platform_api.g.dart`; `backup_folders.dart`.
- [ ] **Adım 4:** `BackupFolders.kt`. Seçici `DocumentFiles.pick` ile aynı `activityResultRegistry` kalıbını kullanır (`ActivityResultContracts.OpenDocumentTree()`, girdi `null`). Seçimden sonra `takePersistableUriPermission(uri, READ|WRITE)`. Görünen ad `buildDocumentUriUsingTree(tree, getTreeDocumentId(tree))` sorgusunun `COLUMN_DISPLAY_NAME`'i, yoksa ağaç belge kimliğinin son parçası. Dosya işlemleri `Dispatchers.IO`'da:
  - **`write`:** `createDocument(parent, mimeType, name)` ile yazar, geri okuyup karşılaştırır. Tutmazsa yeni belgeyi siler. `finally` içinde `bytes.fill(0)`.
  - **`list`:** `buildChildDocumentsUriUsingTree` sorgusu.
  - **`delete`:** adı eşleşen çocukları `deleteDocument` ile siler.
  - **Hatalar:** `SecurityException`, `IOException`, `IllegalArgumentException` ve `FileNotFoundException` yakalanır; `write`/`delete` için başarısız, `list` için `null` döner.
- [ ] **Adım 5:** `MainActivity` ve `bootstrap.dart` bağlantısı, `FakeBackupFolders` ve `pumpKeyKey(folders:)`.
  - `FakeBackupFolders`'ın alanları: `Map<String, Map<String, Uint8List>> files`, `Set<String> granted`, `bool failWrites`, `FolderPick nextPick`, `List<String> released`.
- [ ] **Adım 6:** `flutter test test/core/platform/backup_folders_test.dart` → PASS; `flutter analyze` temiz. `cd android && ./gradlew :app:compileDebugKotlin` derleniyor.
- [ ] **Adım 7: Commit.** `özellik(yedek): klasör seçme ve klasöre yazma köprüsü`

### Görev 2: Dosya adı ve budama kuralı

**Dosyalar:**
- Oluştur: `lib/features/backup/application/auto_backup_files.dart`
- Test: `test/features/backup/auto_backup_files_test.dart`

**Arayüzler:**
- Üretir:
  ```dart
  abstract final class AutoBackupFiles {
    static const prefixes = {'keykey-otomatik', 'keykey-auto'};
    static const keepDays = 14;
    static String nameFor(DateTime time, {required String prefix}); // yerel saat
    static DateTime? parse(String name);             // kalıba tam uymazsa null; dönen değer yerel saat
    static List<String> toDelete(Iterable<String> names);
  }
  ```

- [ ] **Adım 1: Başarısız testler.**
  - `nameFor(DateTime(2026, 11, 18, 15, 30, 12), prefix: 'keykey-otomatik')` == `'keykey-otomatik-2026-11-18-153012.keykey'`; tek haneli ay, gün, saat sıfırla dolar (`2026-01-05-090501`).
  - `parse` gidiş-dönüş verir. "Gözden geçirmede dikkat 1"deki beş ad ve `KEYKEY-OTOMATIK-…` için `null` döner.
  - `toDelete`:
    - aynı günden üç dosyada en yenisi kalır, ikisi silinir;
    - 16 farklı günde en eski iki gün silinir;
    - iki önek karışıkken birlikte sayılır;
    - kalıba uymayan adlar hiçbir durumda listede olmaz;
    - boş liste boş döner.
- [ ] **Adım 2:** `flutter test test/features/backup/auto_backup_files_test.dart` → FAIL.
- [ ] **Adım 3:** Uygula. `parse` tam eşleşen bir `RegExp` kullanır, ardından `DateTime`'ın alanları geri okunarak denetlenir (ay 13, gün 32, saat 24 reddedilir).
- [ ] **Adım 4:** Test → PASS.
- [ ] **Adım 5: Commit.** `özellik(yedek): otomatik yedek dosya adı ve budama kuralı`

### Görev 3: Ayar kaydı sürüm 5

**Dosyalar:**
- Değiştir: `lib/features/settings/data/app_settings.dart`
- Değiştir: `lib/features/settings/application/settings_controller.dart`
- Test: `test/features/settings/app_settings_test.dart`, `test/features/settings/settings_test.dart`

**Arayüzler:**
- Üretir:
  ```dart
  final class AutoBackupFolder { const new({required this.uri, required this.name}); final String uri; final String name; }
  // AppSettings: final AutoBackupFolder? autoBackupFolder; currentVersion = 5
  AppSettings withAutoBackupFolder(AutoBackupFolder? folder); // null verince temizler
  // SettingsController:
  Future<void> setAutoBackupFolder(AutoBackupFolder? folder);
  ```
- JSON: v4 anahtarları + `"autoBackupFolder": null | {"uri": "<content://…>", "name": "<ad>"}`. Tam iki anahtar, ikisi de boş olmayan metin, `uri` `content://` ile başlar.

- [ ] **Adım 1: Başarısız testler.**
  - v5 gidiş-dönüş, klasörlü ve klasörsüz.
  - v4 baytları aynen okunur, `autoBackupFolder == null`.
  - "Gözden geçirmede dikkat 5"teki bozuk v5 içerikleri `tryParse` → `null`.
  - `withAutoBackupFolder(null)` diğer alanları korur.
  - `SettingsController.setAutoBackupFolder` kaydeder ve durumu günceller.
- [ ] **Adım 2:** İlgili testler → FAIL.
- [ ] **Adım 3:** Uygula. `copyWith` bu alana dokunmaz; temizleme yalnızca `withAutoBackupFolder` ile.
- [ ] **Adım 4:** Testler → PASS. Eski sürüm örnekleri ve yedek uyumluluk testleri de geçiyor (`flutter test test/features/settings test/features/backup`).
- [ ] **Adım 5: Commit.** `özellik(ayarlar): ayar kaydı sürüm 5, otomatik yedek klasörü`

### Görev 4: Otomatik yedek denetleyicisi

**Dosyalar:**
- Oluştur: `lib/features/backup/application/auto_backup_controller.dart`
- Değiştir: `lib/app/app.dart` (`KeyKeyApp.build` içinde `ref.watch(autoBackupControllerProvider)`, böylece yalnızca ana uygulamada çalışır, otomatik doldurma motorunda çalışmaz)
- Test: `test/features/backup/auto_backup_controller_test.dart`

**Arayüzler:**
- Tüketir: Görev 1 `backupFoldersProvider`, Görev 2 `AutoBackupFiles`, Görev 3 `AppSettings.autoBackupFolder` ve `setAutoBackupFolder`, `backupServiceProvider`, `backupClockProvider`, `settingsControllerProvider.notifier.recordBackup`, `vaultControllerProvider` ve `addLockListener`, `loginsControllerProvider`, `otpsControllerProvider`.
- Üretir:
  ```dart
  enum AutoBackupProblem { noAccess, writeFailed }
  final class AutoBackupStatus { const new({this.running = false, this.problem}); final bool running; final AutoBackupProblem? problem; }
  final autoBackupDelayProvider = Provider<Duration>((ref) => const Duration(seconds: 5));
  final autoBackupPrefixProvider = Provider<String>(...); // cihaz diline göre çözülen AppLocalizations.autoBackupFilePrefix
  final autoBackupControllerProvider = NotifierProvider<AutoBackupController, AutoBackupStatus>(AutoBackupController.new);
  class AutoBackupController extends Notifier<AutoBackupStatus> {
    Future<bool> backUpNow();                       // değişiklik ölçütüne bakmadan yazar; kapalıysa false
    Future<bool> useFolder(FolderPicked folder);    // eskisini bırakır, ayara yazar, hemen yedekler
    Future<void> disable();                         // izni bırakır, ayarı temizler, durumu sıfırlar
  }
  ```
- **Davranış:**
  - Ayarlar yüklendiğinde (`null` → değer) ve parola ya da 2FA listesi değiştiğinde zamanlayıcı `autoBackupDelayProvider` kadar ertelenir; her yeni tetik zamanlayıcıyı baştan kurar.
  - Süre dolunca yazılır, ama yalnızca şunlar doğruysa: klasör var, `latestChange != null` ve (`lastBackupAt == null` ya da `latestChange.isAfter(lastBackupAt)`).
  - Yazma sırası:
    1. `hasAccess` denetlenir.
    2. Yedek `create(session, now)` ile üretilir.
    3. `write`.
    4. `recordBackup(now)`.
    5. `list` ve `AutoBackupFiles.toDelete`, sonra `delete`.
  - Aynı anda tek iş. Sürerken gelen tetik iş bitince bir kez daha çalışır.
  - Kilit dinleyicisi zamanlayıcıyı iptal eder ve durumu sıfırlar.

- [ ] **Adım 1: Başarısız testler.**
  - Hepsi `fakeAsync` içinde, `ProviderContainer` ve `FakeVaultService`, `FakeBackupFolders`, `FakeBackupService`, `FakeSettingsRepository` ile kurulur.
  - **Tetikler ve ölçüt:**
    - Klasör yokken hiçbir şey yazılmaz.
    - Kasa açılıp ayarlar yüklenince, son değişim son yedekten yeniyse 5 sn sonra tek dosya yazılır. Adı `keykey-otomatik-…`, son yedek zamanı `now`.
    - Son değişim son yedekten eskiyse yazılmaz.
    - 5 sn içinde gelen üç değişiklik tek yazmaya iner.
  - **Hata:**
    - `hasAccess == false` → yazılmaz, `problem == noAccess`.
    - `failWrites` → `problem == writeFailed`, `list`/`delete` çağrılmaz, son yedek zamanı ilerlemez.
  - **Budama:** başarılı yazmadan sonra aynı günün eski otomatik dosyası silinir, `keykey-yedek-…` kalır.
  - **Kilit:**
    - Zamanlayıcı beklerken kasa kilitlenirse yazılmaz.
    - Yazma sürerken kilitlenirse iş istisnasız biter.
  - **Elle işlemler:**
    - `backUpNow` ölçüte bakmadan yazar.
    - `useFolder` eski uri'yi `release` eder, ayara yazar ve yedekler.
    - `disable` izni bırakır, ayarı temizler, dosyalara dokunmaz.
- [ ] **Adım 2:** `flutter test test/features/backup/auto_backup_controller_test.dart` → FAIL.
- [ ] **Adım 3:** Uygula. `KeyKeyApp`'te `ref.watch`.
- [ ] **Adım 4:** Test → PASS; tüm `flutter test` yeşil.
- [ ] **Adım 5: Commit.** `özellik(yedek): otomatik yedek denetleyicisi`

### Görev 5: Arayüz

**Dosyalar:**
- Oluştur: `lib/features/backup/presentation/auto_backup_tile.dart`
- Değiştir: `lib/features/backup/presentation/backup_section.dart` (grubun ilk satırı `AutoBackupTile`)
- Değiştir: `lib/features/backup/presentation/backup_status_card.dart` (durum metninin altında otomatik yedek satırı)
- Değiştir: `lib/features/settings/presentation/change_password_screen.dart` (`PasswordAccepted`'da `unawaited(...backUpNow())`)
- Değiştir: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/backup/auto_backup_tile_test.dart`, `test/features/backup/backup_section_test.dart`

**Arayüzler:**
- Tüketir: Görev 4 `autoBackupControllerProvider` ve `useFolder`/`disable`/`backUpNow`, Görev 1 `backupFoldersProvider.pick`. Seçici `externalActivityGateProvider.notifier.run` içinde açılır.
- Metin anahtarları:
  - Ana metinler: `autoBackupTitle`, `autoBackupOff`, `autoBackupOn(folder)`, `autoBackupIntro`.
  - Durum ve düğmeler: `autoBackupNoAccess`, `autoBackupWriteFailed`, `autoBackupChooseFolder`, `autoBackupChangeFolder`, `autoBackupNow`.
  - Bildirimler: `autoBackupEnabled`, `autoBackupDisabled`, `autoBackupPickFailed`, `autoBackupSaved`.
  - Dosya adı ve kart: `autoBackupFilePrefix` ("keykey-otomatik" / "keykey-auto"), `backupCardAuto(folder)`.
  - `changePasswordBackupNote` güncellenir: klasördeki eski otomatik yedekler de eski parolayla açılır.

- [ ] **Adım 1: Başarısız testler.**
  - **Kapalıyken:** satır `autoBackupOff` metnini ve kapalı anahtarı gösterir.
  - **Açmak:** anahtara dokununca açıklama penceresi çıkar.
    - "Klasör seç" → `FolderPicked` → ayar klasörlü, ilk yedek yazıldı, "Otomatik yedek açıldı" bildirimi.
    - Seçici `FolderPickCancelled` → kapalı kalır, yazma yok.
  - **Açıkken:**
    - Satıra dokununca alt pencerede "Klasörü değiştir" ve "Şimdi yedekle".
    - Anahtarı kapatınca `disable`, bildirim.
  - **Hata:** `problem == noAccess` iken satırda `autoBackupNoAccess` görünür.
  - **Yedek kartı:** klasör açıkken klasör adını gösterir, hata varken uyarıyı.
  - **Parola değişince:** otomatik yedek açıksa klasöre yeni bir dosya yazılır.
- [ ] **Adım 2:** İlgili testler → FAIL.
- [ ] **Adım 3:** Uygula. Mevcut bileşenler kullanılır: `KkSection` içinde `ListTile` + `Switch`, `showKkConfirm`, `showKkSheet` ve `KkSheetContent`, `kkSnackFor`, `KkIconBox(icon: Icons.sync_rounded)`. `flutter gen-l10n`.
- [ ] **Adım 4:** Testler, `flutter analyze` ve tüm `flutter test` → PASS. Erişilebilirlik testleri de geçiyor (`test/accessibility`).
- [ ] **Adım 5: Commit.** `özellik(yedek): ayarlarda otomatik yedek`

### Görev 6: Emülatörde deneme

- [ ] **Adım 1:** Medium_Phone_API_37.0'ı başsız açıp hata ayıklama APK'sını kur (`-gpu host`). Gerçek arayüz yolunu izle:
  1. Kasa kur, bir kayıt ekle.
  2. Ayarlar → Otomatik yedek → "Klasör seç".
  3. Seçicide `Documents` altında yeni klasör `KeyKey` oluştur → "Bu klasörü kullan" → izin ver.
  4. `adb shell ls /sdcard/Documents/KeyKey` ile dosyayı gör.
  5. İkinci kaydı ekle, 5 sn sonra dosya güncellendi mi bak; aynı gün tek dosya kalmalı.
- [ ] **Adım 2:** Dosyayı başka bir temiz kurulumda "Yedekten geri yükle" ile aç. Kayıtlar gelmeli.
- [ ] **Adım 3:** Klasörü `adb shell rm -r` ile sil, kayıt ekle. Ayarlarda hata görünmeli; "Klasörü değiştir" ile düzelmeli.
- [ ] **Adım 4:** Emülatörü kapat, KeyKey_API_30'u aç. Seçim, yazma ve geri yüklemeyi tekrarla.
- [ ] **Adım 5:** Sonuçları tasarım belgesine "Deneme" notu olarak yaz.

### Görev 7: Belgeler, sürüm ve faz PR'ı

**Dosyalar:**
- Değiştir: `resources/docs/guvenlik-tasarimi.md`:
  - "Yedekleme" altına "Otomatik yedek" alt bölümü;
  - ayar kaydı düz metnine ve sürüm listesine `autoBackupFolder` (sürüm 5);
  - bilinen sınırlardaki eski parola maddesine otomatik yedekler.
- Değiştir: `resources/docs/kullanim.md` (yedek bölümüne otomatik yedek ve eşitleme önerisi)
- Değiştir: `resources/CHANGELOG.md`, `fastlane/metadata/android/{tr-TR,en-US}/changelogs/6.txt`, `pubspec.yaml` (`version: 1.2.0+6`)
- Değiştir: `resources/yol-haritasi.md` (Faz 12 kutuları, durum)

- [ ] **Adım 1:** Belgeler ve sürüm.
- [ ] **Adım 2:** Tüm kontroller. Yayın APK'sı için `resources/scripts/check-release-apk.sh` çalışır ve yeni izin olmadığını gösterir.
- [ ] **Adım 3:** Bağımsız gözden geçirme: tüm dal için taze bir alt ajan. Bulgular düzeltilir.
- [ ] **Adım 4:** `git log HEAD..origin/main` boş değilse `main` birleştirilir. PR "Faz 12: Otomatik yedek" açılır (`Closes #137`), CI yeşilse birleştirilir.
- [ ] **Adım 5:** Milestone ve yol haritası güncellenir. Telefon denemesi ve yayın proje sahibini bekler.
