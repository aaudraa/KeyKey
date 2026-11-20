# Senkron: uygulama planı

> **Yürütme:** superpowers:executing-plans (satır içi). Adımlar `- [ ]` ile izlenir. Görev başlıkları betikler için İngilizce "Task N".

**Amaç:** Aynı kasayı kullanan telefonlar, kullanıcının WebDAV klasöründeki telefon başına şifreli senkron dosyalarıyla kayıt kayıt eşitlenir.

**Mimari:**
- Silme kayıtları ve yuva zamanları veritabanında (şema 2).
- Senkron dosyası yedek kapsayıcısında, içerik sürümü 4 ve `sync` nesnesiyle (`BackupCodec`).
- Birleştirme ağ bilmeyen saf bir sınıftır (`SyncMerger`) ve tek SQLite işlemiyle uygulanır (`VaultStore.applySync`).
- Ağ yalnızca `WebDavClient`'ta; `SyncTransport` arayüzünün arkasında.
- `SyncService` bir eşitlemeyi yürütür, `SyncController` tetikleri ve durumu tutar.

**Teknoloji:** Flutter, Riverpod, drift, libsodium; yeni bağımlılık `xml` (saf Dart, MIT).

**Tasarım:** [senkron.md](senkron.md)

## Genel kısıtlar

- Dal `faz/19-senkron`, issue #160; commit'ler `Refs #160`, PR `Closes #160`.
- Türkçe metin, İngilizce kod adları; commit biçimi `<tür>(<alan>): …`.
- Güvenlik tasarımı her kural değişikliğiyle aynı commit'te güncellenir.
- Senkron dosyası adı `keykey-sync-<cihaz>.keykey`, ara ad `….part`; `<cihaz>` = `autoBackupDeviceProvider`.
- Yalnızca HTTPS; `http://` yalnızca `127.0.0.1`, `localhost`, `::1`. Yönlendirme izlenmez. Bağlanma 10 sn, istek 60 sn. Liste yanıtı en çok 1 MiB, dosya en çok `BackupCodec.maxFileBytes` (64 MiB).
- Saat koruması: bu telefonun saatinden 24 saatten ileri zaman taşıyan dosya bütünüyle yok sayılır.
- Eşitleme tetikleri: kasa açılınca; kayıt değişince 5 sn sonra; öne gelince son eşitlemeden 60 sn geçtiyse; elle.
- Hata mesajı, günlük ve durum metni adres yolunu, kullanıcı adını ve uygulama parolasını taşımaz.
- Dokunma alanları 48 dp'nin altına inmez; %200 yazıda ve 320 dp'de taşma yok.
- Sürüm `1.8.0+12`; ayar kaydı sürüm 7; yedek içerik sürümü 4; veritabanı şeması 2; kullanım koşulları sürüm 3.

## İnceleme odağı

1. **Yarım eşitleme:** ağ ya da kilit eşitlemenin ortasında koparsa kasa ya eski halinde ya da birleşmiş halinde olmalı, ikisinin karışımı değil; sunucuda yarım dosya görünmemeli. Test: Task 6'da indirme sonrası, `applySync` öncesi ve yükleme sırasında hata.
2. **Eski telefonun dönüşü:** aylarca kapalı kalmış bir telefonun dosyası, sonradan silinen ya da değişen kayıtları geri getirmemeli. Test: Task 3, üç telefonla.
3. **Aynı kayıt iki telefonda:** otomatik doldurmanın yeni parolası, öteki telefondaki favori değişikliğine yenilince kaybolmamalı. Test: Task 4.
4. **Başka kasa ya da karışık klasör:** başka bir kasanın dosyası olan klasörde bu telefon dosya yazmamalı ve hiçbir kayıt alınmamalı. Test: Task 6.
5. **Senkron açıkken geri yükleme:** geri yüklenen kayıt bir sonraki eşitlemede yeniden silinmemeli; değiştirerek geri yükleme senkron üzerinden kayıt silmemeli. Test: Task 10.

---

### Task 1: Silme kayıtları ve yuva zamanları (şema 2)

**Dosyalar:** `lib/core/storage/vault_database.dart` (+ `.g.dart` yeniden üretilir), `lib/core/storage/vault_store.dart`, `lib/core/vault/vault_service.dart`; testler `test/core/storage/*`, `test/core/vault/*`.

- **Arayüz:**
  - Tablo `Tombstones` (`id` blob 16 bayt PK, `deleted_at` int). `VaultMeta`'ya `password_changed_at`, `recovery_changed_at` (int, boş olabilir). `currentSchemaVersion = 2`; `onUpgrade` 1→2 tabloyu ve sütunları ekler, başka sürümde yine `UnsupportedSchemaException`.
  - `final class StoredTombstone { Uint8List id; DateTime deletedAt; }`
  - `final class HeaderTimes { DateTime? passwordChangedAt; DateTime? recoveryChangedAt; }`
  - `VaultStore.deleteRecord(Uint8List id, {DateTime? deletedAt})`: satırı siler, aynı işlemde silme kaydını yazar (`deletedAt ?? DateTime.now()`; varsa büyük olan kalır). Ayar kaydının kimliğinde silme kaydı yazmaz.
  - `VaultStore.allTombstones() → Future<List<StoredTombstone>>`, `readHeaderTimes() → Future<HeaderTimes>`.
  - `VaultStore.updateHeader(VaultHeader header, {DateTime? passwordChangedAt, DateTime? recoveryChangedAt})`: verilen zamanları aynı işlemde yazar, verilmeyenlere dokunmaz.
  - `VaultStore.replaceVault(header, records, {List<StoredTombstone> tombstones = const [], HeaderTimes times = const HeaderTimes()})`: eski silme kayıtlarını siler, verilenleri ve zamanları yazar.
  - `VaultService._rewrap` `passwordChangedAt: now`, `confirmNewRecoveryKey` `recoveryChangedAt: now` verir (`now` servisin saatinden).
- [ ] Test: `deleteRecord` silme kaydı yazar; iki kez silmede büyük zaman kalır; ayar kaydı için yazmaz.
- [ ] Test: şema 1 veritabanı (eski şemayla elle kurulan dosya) açılınca kayıtlar ve üst bilgi korunur, `tombstones` boş, zamanlar `null`.
- [ ] Test: parola değişikliği yalnızca `passwordChangedAt`'i, kurtarma yenilemesi yalnızca `recoveryChangedAt`'i yazar; kurtarmayla yeni parola `passwordChangedAt` yazar.
- [ ] Test: `replaceVault` eski silme kayıtlarını siler, verilenleri yazar.
- [ ] Mevcut silme yolları (kalıcı silme, çöpü boşaltma, 30 günlük temizlik; parola, 2FA, kart, not) silme kaydı bıraktığını tek bir depo testiyle doğrula.
- [ ] Güvenlik tasarımı: Depolama tablosu, silme kayıtları paragrafı, şema sürümü.
- [ ] Commit `özellik(kasa): silme kayıtları ve yuva zamanları`.

### Task 2: Ayarlar sürüm 7 ve yedek içerik sürümü 4

**Dosyalar:** `lib/features/settings/data/app_settings.dart`, `lib/core/backup/backup_codec.dart`, `lib/features/backup/application/restore_service.dart`; testler `test/features/settings/*`, `test/core/backup/*`.

- **Arayüz:**
  - `final class SyncSettings { Uri folder; String username; String appPassword; DateTime? lastSyncAt; String? lastDigest; }` JSON anahtarları `folder`, `username`, `appPassword`, `lastSyncAt`, `lastDigest`; `tryParse` katı (eksik/fazla alan → `null`, `folder` https ya da yerel http).
  - `AppSettings.sync` (`SyncSettings?`), `copyWith(sync:, clearSync:)`, `currentVersion = 7`; 4-6 okunur, `sync` yok sayılır.
  - `final class SyncInfo { String device; String? deviceName; DateTime? passwordChangedAt; DateTime? recoveryChangedAt; List<StoredTombstone> deleted; }`
  - `BackupCodec.payloadVersion = 4`; `encode(..., SyncInfo? sync)`; `BackupContents.sync` (`SyncInfo?`). `sync` yalnızca sürüm 4'te; `sync` varken `settings` türünde kayıt ve yinelenen silme kaydı kimliği reddedilir; `device` 6 küçük onaltılık karakter; `deviceName` en çok 64 karakter.
  - Kayıt içerik sürümlerini yedeğin içerik sürümüyle sabitleyen test, ayar 7 / yedek 4 olarak güncellenir.
- [ ] Test: sürüm 7 yazılır ve okunur; 6 ve öncesi `sync` olmadan okunur; bozuk `sync` (http uzak adres, eksik alan) ayarları reddetmez, yalnızca `sync`'i `null` yapar.
- [ ] Test: sürüm 4 `sync`'li ve `sync`'siz yazılır ve okunur; sürüm 3 `sync`'li reddedilir; sürüm 5 `NewerBackupException`.
- [ ] Test: `sync`'li dosyada `settings` kaydı, yinelenen silme kaydı, geçersiz cihaz kimliği reddedilir.
- [ ] Test: Geri yükle, `sync`'li dosyayı yedek gibi açar (kayıt sayıları doğru).
- [ ] Güvenlik tasarımı: yedek biçimi (sürüm 4, `sync`), ayar kaydı sürüm 7.
- [ ] Commit `özellik(yedek): içerik sürümü 4 ve senkron bilgileri`.

### Task 3: Birleştirme: kayıtlar, silmeler, saat koruması

**Dosyalar:** yeni `lib/features/sync/application/sync_merger.dart`, `lib/core/storage/vault_store.dart`; test `test/features/sync/sync_merger_test.dart`, `test/core/storage/vault_store_sync_test.dart`.

- **Arayüz:**
  - `final class SyncSource { String device; String? deviceName; VaultHeader header; BackupContents contents; DateTime? modified; }` (bir cihaz dosyasının açılmış hali).
  - `final class LocalState { List<StoredRecord> records; List<StoredTombstone> tombstones; VaultHeader header; HeaderTimes times; }`
  - `final class SyncPlan { List<StoredRecord> put; List<Uint8List> delete; List<StoredTombstone> addTombstones; List<Uint8List> removeTombstones; VaultHeader? header; HeaderTimes? times; List<SyncIssue> issues; bool get isEmpty; }`
  - `sealed class SyncIssue` alt türleri: `ClockAhead(device)`, `UnreadableDevice(device)`, `TypeConflict(device)`, `NewerApp(device)` (Task 6 verir), `PasswordAdopted()`, `RecoveryAdopted()`, `SlotsDiffer(device)` (Task 4 doldurur).
  - `SyncMerger.new({required RecordCipher cipher, required DateTime now})`; `SyncPlan merge(LocalState local, List<SyncSource> sources)`.
  - Kurallar tasarımın [Birleştirme](senkron.md#birleştirme) bölümündeki sırayla: en iyi kayıt (`updatedAt`, eşitse blob bayt sırası), silme kaydı `>=` kazanır, yenilen silme kaydı kaldırılır, tür çakışması ve açılmayan kayıt o kaynağı bütünüyle düşürür, 24 saatten ileri zaman o kaynağı düşürür. Yalnızca yerele yazılacak uzak kayıtlar çözülüp içerik biçimiyle doğrulanır (`LoginContent`, `OtpContent`, `CardContent`, `NoteContent`; restore'daki kural ortak bir yardımcıya taşınır).
  - `VaultStore.applySync(SyncPlan plan)`: tek işlem; `put` için `putRecord`, `delete` için silme (bu yolda ek silme kaydı yazmaz, `addTombstones` yazar), üst bilgi ve zamanlar.
- [ ] Test (iki telefon): yeni olan kazanır; eşit zamanda iki farklı sırada aynı sonuç.
- [ ] Test: silme kaydı eski değişikliği siler; daha yeni değişiklik silmeyi yener ve silme kaydı kaldırılır; eşit zamanda silme kazanır.
- [ ] Test (üç telefon, inceleme odağı 2): C'nin aylar önceki dosyası, A'da kalıcı silinen ve B'de değişen kayıtları geri getirmez.
- [ ] Test: bir kaynağın kaydı açılmazsa o kaynak düşer, `UnreadableDevice` verilir, öteki kaynak birleşir; tür çakışmasında `TypeConflict`.
- [ ] Test: 24 saat + 1 ms ileri `updatedAt` ya da `deletedAt` taşıyan kaynak düşer, `ClockAhead`; tam 24 saat kabul.
- [ ] Test: yerel ve uzak aynıysa plan boş.
- [ ] Test: `applySync` hata verirse (sahte depo işlemin ortasında fırlatır) kasa değişmez.
- [ ] Commit `özellik(senkron): kayıt birleştirme ve silme kayıtları`.

### Task 4: Birleştirme: kaybeden parola ve yuvalar

**Dosyalar:** `lib/features/sync/application/sync_merger.dart`, `lib/features/vault/data/login_content.dart`, `lib/core/crypto/vault_header.dart`; testler aynı dosyalar.

- **Arayüz:**
  - `LoginContent.withRescuedPassword(String password, DateTime changedAt) → LoginContent?`: parola boşsa, şimdiki parolaysa ya da geçmişteyse `null`; değilse geçmişin başına ekler, 10 sınırı.
  - Birleştirmede kazanan ve kaybeden ikisi de `login` ise kurtarma: yeni blob `cipher.encrypt`, `updatedAt = kazanan + 1 ms`, `createdAt` kazananınki.
  - `VaultHeader.withPasswordSlotFrom(VaultHeader other)` (parola yuvası, KDF parametreleri, tuz) ve mevcut `withRecoverySlot`.
  - Yuva birleştirme tasarımın [Ana parola](senkron.md#ana-parola-ve-kurtarma-anahtarı-değişikliği) bölümündeki gibi: zaman büyükse al; ikisi `null` ve yuvalar farklıysa alma, `SlotsDiffer(device)`; eşit zaman ve farklı yuvada bayt sırası; `vaultId` farklıysa kaynak düşer.
- [ ] Test (inceleme odağı 3): A'da yeni parola (T1), B'de aynı kaydın favorisi (T2 > T1); B kazanır, A'nın parolası geçmişte, `updatedAt = T2 + 1 ms`.
- [ ] Test: iki telefon aynı kurtarmayı yapınca içerikler aynı; ikinci birleştirmede plan boş (kural yeniden tetiklenmez).
- [ ] Test: parola aynı ya da geçmişteyse kurtarma yok; parola dışı türde kurtarma yok.
- [ ] Test: A kurtarma anahtarını yeniler (gün 1), B parolayı değiştirir (gün 3); birleşik üst bilgide A'nın kurtarma yuvası ve B'nin parola yuvası; yeni parola ve yeni kurtarma anahtarı kasayı açar, eskiler açmaz (gerçek `VaultCrypto`).
- [ ] Test: zamanlar `null` ve yuvalar farklı → üst bilgi alınmaz, `SlotsDiffer`; eski zaman alınmaz.
- [ ] Commit `özellik(senkron): kaybeden parolayı ve yuvaları birleştirme`.

### Task 5: WebDAV istemcisi

**Dosyalar:** yeni `lib/core/network/webdav_client.dart`, yeni `lib/features/sync/data/sync_transport.dart`, `pubspec.yaml` (`xml`), `test/core/network/network_audit_test.dart`, `resources/docs/bagimliliklar.md`; testler `test/core/network/webdav_client_test.dart` (yerel `HttpServer` ile sahte WebDAV), `test/core/network/fixtures/propfind_*.xml`.

- **Arayüz:**
  - `final class RemoteFile { String name; String? etag; int? size; DateTime? modified; }`
  - `abstract interface class SyncTransport { Future<void> ensureFolder(); Future<List<RemoteFile>> list(); Future<Uint8List> read(String name); Future<void> write(String name, Uint8List bytes); Future<void> delete(String name); }`
  - `enum SyncFailureKind { offline, unauthorized, certificate, redirect, notFound, server, insufficientStorage, tooLarge, badResponse }`; `final class SyncTransportException implements Exception { SyncFailureKind kind; }` mesajı yol ve kimlik taşımaz.
  - `final class WebDavClient implements SyncTransport { new({required Uri folder, required String username, required String password, Duration connectTimeout = 10 s, Duration requestTimeout = 60 s}) }`; geçersiz şemada `ArgumentError`.
  - `list` yalnızca klasörün doğrudan çocuklarını, klasör olmayanları ve adı `keykey-sync-` ile başlayıp `.keykey` ile bitenleri döndürür; `href` yüzde kodlu ve tam ya da göreli olabilir.
  - `write`: `PUT name.part` → `GET` bayt bayt karşılaştır → `MOVE` (`Destination` tam URL, `Overwrite: T`); 405/501'de `PUT name` ve `DELETE name.part`; karşılaştırma tutmazsa `DELETE name.part` ve `badResponse`.
  - `ensureFolder`: `PROPFIND` 404 ise `MKCOL`.
- [ ] Test: üç `PROPFIND` örneği (Nextcloud `d:`, Apache `D:`/`lp1:`, rclone varsayılan ad alanı) aynı listeyi verir; alt klasör ve başka dosyalar elenir.
- [ ] Test: yazma sırası `PUT .part`, `GET`, `MOVE`; `MOVE` 405 iken doğrudan yazma; geri okuma tutmazsa ara dosya silinir.
- [ ] Test: 401/403 `unauthorized`, 404 `notFound`, 3xx `redirect` (yönlendirme izlenmez, ikinci istek gitmez), 507 `insufficientStorage`, 5xx `server`, zaman aşımı `offline`, büyük yanıt `tooLarge`.
- [ ] Test: `http://example.com` reddedilir; `http://127.0.0.1` kabul; her istekte Basic başlığı ve `User-Agent: KeyKey`; hata mesajında kullanıcı adı, parola ve yol yok.
- [ ] Test: ağ denetimi iki dosyaya izin verir; üçüncü bir dosyadaki `HttpClient` yakalanır.
- [ ] Güvenlik tasarımı: Ağ paragrafı ve WebDAV istemcisi kuralları; bağımlılıklar belgesi.
- [ ] Commit `özellik(senkron): WebDAV istemcisi`.

### Task 6: Eşitleme servisi

**Dosyalar:** yeni `lib/features/sync/application/sync_service.dart`, `pigeons/*.dart` ve üretilen `PlatformApi.g.*` (`AppPackagesApi.deviceModel()`), `android/.../AppPackages.kt`, `lib/core/platform/app_packages.dart`; test `test/features/sync/sync_service_test.dart` (bellekte `FakeSyncTransport`, gerçek SQLite ve libsodium).

- **Arayüz:**
  - `AppPackages.deviceModel() → Future<String>` (`Build.MODEL`, 64 karakterde kesilir); `deviceModelProvider` (`FutureProvider<String>`).
  - `final class SyncResult { DateTime at; List<SyncIssue> issues; List<SyncDevice> devices; bool uploaded; bool changedLocal; }`; `final class SyncDevice { String device; String? name; DateTime? modified; bool self; }`.
  - `sealed class FolderState`: `FolderEmpty`, `FolderSameVault`, `FolderOtherVault(BackupFile newest)`, `FolderMixedVaults`.
  - `SyncService.new({VaultStore store, BackupCodec codec, SodiumSumo sodium, SyncTransport Function(SyncSettings) transport, String device, Future<String> Function() deviceName, DateTime Function() now})`.
  - `Future<FolderState> inspect(SyncSettings settings, Uint8List vaultId)`: listeler, her dosyanın yalnızca başını okur (`parse`).
  - `Future<SyncResult> sync(VaultSession session, SyncSettings settings, {Map<String, String> etags})`: listele → `etags`'ta aynı olmayanları indir (kendi dosyası dahil) → `parse`/`open` (kasa anahtarı) → `vaultId` farklı dosya varsa `OtherVaultException` ve hiçbir şey yazılmaz → `SyncMerger` → `applySync` → kendi dosyasını `encode` (ayar kaydı hariç kayıtlar, silme kayıtları, yuva zamanları, `SyncInfo`) → özet `lastDigest`'ten farklıysa `write` → `SyncResult`. Daha yeni içerik sürümlü dosya `NewerApp(device)` olarak düşer. `final class OtherVaultException implements Exception`. Özet: BLAKE2b-256, sıralı (kimlik, tür, `updatedAt`, blob özeti), silme kayıtları, üst bilgi JSON'u, yuva zamanları; onaltılık.
  - `Future<void> removeDevice(SyncSettings settings, String device)`.
- [ ] Test: boş klasör → yükleme yapılır, dosya adı `keykey-sync-<cihaz>.keykey`, içerik sürümü 4, ayar kaydı yok.
- [ ] Test: iki `SyncService` (iki ayrı SQLite, aynı kasa) aynı sahte klasörde: A kayıt ekler, B görür; B siler, A'da silinir; eşitleme tekrarında yükleme yok (`uploaded == false`).
- [ ] Test: değişmeyen `etag`'li dosya indirilmez (sahte taşıyıcı okuma sayar).
- [ ] Test (inceleme odağı 4): klasörde başka `vaultId`li dosya → `OtherVaultException`, yerel kasa ve klasör değişmez; `inspect` dört durumu ayırır.
- [ ] Test (inceleme odağı 1): indirmede hata → kasa değişmez; `write` hata verince kasa birleşmiş halde, `lastDigest` güncellenmez (sonraki eşitleme yeniden yükler).
- [ ] Test: kendi dosyası, yerel kasada olmayan kaydı geri getirir.
- [ ] Commit `özellik(senkron): eşitleme servisi`.

### Task 7: Eşitleme kontrolcüsü ve tetikler

**Dosyalar:** yeni `lib/features/sync/application/sync_controller.dart`; `lib/features/lock/presentation/auto_lock_scope.dart` ya da uygulama kabuğu (dinleyicinin bağlandığı yer); test `test/features/sync/sync_controller_test.dart`.

- **Arayüz:**
  - `final class SyncStatus { bool enabled; bool running; DateTime? lastSyncAt; SyncFailureKind? failure; List<SyncIssue> issues; List<SyncDevice> devices; }`
  - `syncControllerProvider` (`NotifierProvider<SyncController, SyncStatus>`); `syncDelayProvider` (5 sn), `syncResumeGapProvider` (60 sn), `syncServiceProvider`.
  - `SyncController.syncNow() → Future<SyncStatus>`; `onRecordsChanged()`; `onResumed()`; kasa açılınca kendiliğinden eşitler. Aynı anda tek eşitleme, sürerken gelen tetik bittikten sonra bir kez. Kasa kilitlenince dönem artar, sonuç atılır, `etags` bellekten silinir.
  - Başarıdan sonra ayar kaydına `lastSyncAt` ve `lastDigest` yazılır; `changedLocal` ise `loginsController`, `otpsController`, `cardsController`, `notesController` (var olanlar) yeniden okunur.
  - `PasswordAdopted`/`RecoveryAdopted` bir kez gösterilecek bildirim olarak durumda kalır (`consumeNotice()`).
  - Otomatik doldurma motoru eşitlemez (yalnızca ana uygulamanın kabuğu dinler).
- [ ] Test: kasa açılınca bir eşitleme; kayıt değişince 5 sn sonra bir (peş peşe üç değişiklik tek eşitleme).
- [ ] Test: öne gelince son eşitlemeden 59 sn geçtiyse yok, 60 sn geçtiyse var.
- [ ] Test: eşitleme sürerken `syncNow` → bittikten sonra tam bir tane daha.
- [ ] Test: eşitleme sürerken kilit → sonuç atılır, ayarlar yazılmaz.
- [ ] Test: senkron kapalıyken hiçbir tetik ağa çıkmaz.
- [ ] Commit `özellik(senkron): tetikler ve durum`.

### Task 8: Ayarlar → Senkron ekranları

**Dosyalar:** yeni `lib/features/sync/presentation/sync_screen.dart`, `sync_setup_form.dart`, `sync_devices.dart`; `lib/features/settings/presentation/settings_screen.dart` (satır), `lib/app/router.dart` (`/ayarlar/senkron`), arb (tr, en); testler `test/features/sync/sync_screen_test.dart`, erişilebilirlik testleri.

- **Arayüz:** Ayarlar'da yedek bölümünün altında **Senkron** satırı (`Kapalı` / `Son eşitleme …` / hata). Kapalıyken form: adres (normal klavye `PlainKeyboard.url`), kullanıcı adı, uygulama parolası (`SecretField`, gizli). **Bağlan** → `inspect` → durum:
  - `FolderEmpty`/`FolderSameVault`: açıklama penceresi (tasarımdaki maddeler, ayrı uygulama parolası önerisi dahil) → **Aç** → ayar kaydına `SyncSettings` → `syncNow`.
  - `FolderOtherVault`: "Bu klasörde başka bir KeyKey kasası var." **Bu telefonu o kasaya kat** (Task 11) / **Vazgeç**.
  - `FolderMixedVaults`: "Bu klasörde birden çok kasa var. Boş bir klasör seç."
  - Açıkken: durum, **Şimdi eşitle**, cihaz listesi (model · kimlik · zaman; kendi satırı "Bu telefon"), **Kaldır** (uyarı penceresi), **Senkronu kapat** (pencere, "Bu telefonun sunucudaki dosyasını da sil" işaretli).
  - Hata metinleri `SyncFailureKind` ve `SyncIssue` başına; bildirimler `KkSnack`.
- [ ] Test: boş klasör → pencere → açılır, ayarlarda `SyncSettings`, eşitleme çağrıldı.
- [ ] Test: 401 → "Kullanıcı adı ya da uygulama parolası yanlış." ve ayarlar yazılmaz.
- [ ] Test: başka kasa ve karışık klasör metinleri; karışıkta açma düğmesi yok.
- [ ] Test: Kaldır ve Senkronu kapat pencereleri doğru dosyayı siler; kutu kaldırılınca kendi dosyası silinmez.
- [ ] Test: `PasswordAdopted` bildirimi bir kez gösterilir.
- [ ] Test: 320 dp ve %200 yazıda taşma yok; düğmeler 48 dp; etiketler okunur.
- [ ] Commit `özellik(senkron): ayarlar ekranı`.

### Task 9: Yeni telefonu senkrondan kurmak

**Dosyalar:** `lib/features/onboarding/presentation/onboarding_screen.dart` (kurulum ekranı, **Senkrondan kur**), `lib/features/backup/presentation/restore_screen.dart` (`syncSettings` ve `SyncInfo` alır), `lib/features/backup/application/restore_service.dart` (`replace(..., {SyncSettings? sync, SyncInfo? syncInfo})`); testler `test/features/backup/restore_*`, `test/features/onboarding/*`.

- **Arayüz:** Kurulumda **Senkrondan kur** → Task 8'in formu (kasa yok) → `inspect`: dosya yoksa "Bu klasörde KeyKey senkron dosyası yok."; tek kasa → en son değişen dosya (`modified`, eşitse ada göre) okunur → `RestoreScreen(file:, sync:)` → kilit açma → `replace`: kayıtlar, `syncInfo.deleted` silme kayıtları, yuva zamanları, varsayılan ayarlar + `sync` → kasa açık → `syncNow`.
- [ ] Test: senkron dosyasından kurulan kasada kayıtlar, silme kayıtları ve zamanlar dosyadakiyle aynı; ayar kaydında `sync` var, öteki ayarlar varsayılan.
- [ ] Test: klasörde birden çok kasa → kurulum yapılmaz, metin gösterilir.
- [ ] Test: yanlış parola → hiçbir şey yazılmaz (mevcut restore testinin senkron sürümü).
- [ ] Commit `özellik(senkron): yeni telefonu senkrondan kurma`.

### Task 10: Senkron açıkken geri yükleme

**Dosyalar:** `lib/features/backup/application/restore_service.dart`, `lib/core/storage/vault_store.dart` (`mergeRecords` ve `replaceVault`'a `stampAt` ve silme kaydı kaldırma), `restore_screen.dart` (senkron uyarı metni); testler `test/features/backup/restore_service_test.dart`.

- **Arayüz:**
  - `RestoreService.merge(backup, session, {DateTime? stampAt})`: `stampAt` verilirse eklenen ve güncellenen kayıtların `updatedAt`'i `stampAt`, silme kayıtları kaldırılır. Çağıran senkron açıksa `now` verir.
  - `RestoreService.replace(..., {SyncSettings? sync, SyncInfo? syncInfo, DateTime? stampAt})` (Task 9'un imzası, `stampAt` eklenir): kasa varken çağıran bu telefonun `sync` ayarını verir; yedeğin `vaultId`'si önceki kasanınkiyle aynıysa ayar kaydına konur ve `stampAt` uygulanır, değilse senkron kapalı gelir. Kasa yokken (Task 9) `sync` her zaman konur.
  - Ekran metni (senkron açıkken): "Senkron açık: yedekteki kayıtlar bütün telefonlarda yedekteki haline döner; yedekte olmayan kayıtlar silinmez."
- [ ] Test (inceleme odağı 5): A'da kalıcı silinen kayıt yedekten birleştirerek geri gelir; B'nin silme kaydıyla eşitlenince silinmez.
- [ ] Test: aynı kasada değiştirme senkronu açık tutar, eşitlemeden sonra yedekte olmayan kayıtlar (kendi dosyasından ve B'den) geri gelir.
- [ ] Test: başka kasada değiştirme senkronu kapatır; senkron kapalıyken zamanlar değişmez.
- [ ] Commit `özellik(senkron): senkron açıkken geri yükleme`.

### Task 11: Başka kasası olan telefonu katmak

**Dosyalar:** yeni `lib/features/sync/application/sync_join.dart`, `sync_screen.dart` (akış), `lib/core/vault/vault_service.dart` (oturumu yeni anahtarla değiştirme), `restore_service.dart`; test `test/features/sync/sync_join_test.dart`.

- **Arayüz:** `SyncJoin.join({required VaultSession current, required BackupFile remote, required String secret, required bool isRecoveryKey, required SyncSettings settings}) → Future<VaultSession>`: uzak dosyayı açar (yanlışta `WrongSecretException`, hiçbir şey yazılmaz) → bu telefonun kayıtları (ayar hariç) eski anahtarla çözülüp uzak anahtarla şifrelenir → tek işlem: `replaceVault(uzak üst bilgi, uzak kayıtlar, uzak silme kayıtları, uzak zamanlar)` + yerel kayıtların birleştirilmesi (aynı kimlikte yeni olan; `stampAt` yok) + bu telefonun ayar kaydı (yeni anahtarla, `sync` eklenmiş) → parmak izi yuvası silinir → yeni oturum döner, eski oturum kapanır → `syncNow`. Öncesinde uyarı penceresi: "Bu telefonun ana parolası ve kurtarma anahtarı artık geçmez; senkron kasasınınkiler geçer."
- [ ] Test: katılınca bu telefonun kayıtları kaybolmaz ve yeni anahtarla açılır; uzak kayıtlar gelir; eski ana parola kasayı açmaz, uzak parola açar; parmak izi yuvası yok.
- [ ] Test: yanlış parola ya da işlem ortasında hata → kasa ve oturum eski halinde.
- [ ] Commit `özellik(senkron): başka kasayı senkrona katma`.

### Task 12: Koşullar sürüm 3, gizlilik, belgeler, sürüm

**Dosyalar:** `lib/features/onboarding/data/terms_acceptance.dart` (`currentTermsVersion = 3`), koşul ekranının metni (arb ya da belge, mevcut kaynağı neyse), `resources/docs/kosullar.md`, `terms.md`, `gizlilik.md`, `privacy.md`, `guvenlik-tasarimi.md` (tehdit modeli satırları, bilinen sınırlar, senkron bölümü), `security-summary.md`, `kullanim.md` (Senkron bölümü; "Eşitleme yok" maddesi kalkar; parola sızınca ve telefon çalınınca ne yapılır), `resources/CHANGELOG.md`, `fastlane/metadata/android/{tr-TR,en-US}/changelogs/12.txt`, `pubspec.yaml` (`1.8.0+12`), `resources/yol-haritasi.md`.
- [ ] Test: 2. sürümü kabul etmiş kullanıcıya koşullar yeniden sorulur (mevcut koşul testinin sürüm 3 hali).
- [ ] Commit `belge(senkron): koşullar, gizlilik, kılavuz ve sürüm 1.8.0`.

### Task 13: Cihaz testi, cihaz denemeleri, son gözden geçirme

**Dosyalar:** yeni `integration_test/sync_test.dart` (telefonda `127.0.0.1` üzerinde sahte WebDAV sunucusu, gerçek SQLite ve libsodium: iki kasa durumu birleşir, silme taşınır, yarım yükleme görünmez); `resources/scripts/all-device-tests.sh` listeye ekleme gerekiyorsa.
- [ ] Android 17 ve 11 emülatörlerinde bütün cihaz testleri (ön planda, 10 dakikanın altında adımlarla).
- [ ] Gerçek kullanıcı yolu: bilgisayarda `rclone serve webdav` (gerekirse `winget install Rclone.Rclone`), `adb reverse tcp:8080 tcp:8080`, adres `http://127.0.0.1:8080/keykey`. Telefon 1: kasa, senkronu aç, kayıt ekle. "Telefon 2": uygulama verisini sil → **Senkrondan kur** → kaydı görür; sil → telefon 1'in dosyasıyla geri gelmez; parola değiştir → öteki üst bilgiye geçer.
- [ ] Bağımsız son gözden geçirme (Opus), bulgular, yol haritası, PR `Closes #160`.
