# KeePass içe aktarma uygulama planı

> **Uygulayan için:** Görevler sırayla, satır içinde yürütülür (superpowers:executing-plans). Adımlar `- [ ]` kutularıyla izlenir.

**Amaç:** `.kdbx` dosyasını ana parola ve anahtar dosyasıyla açıp kayıtlarını bugünkü içe aktarma önizlemesine vermek.

**Mimari:** Dart'ta saf bir KDBX okuyucu (başlık → anahtar → şifre çözme → XML → kayıt eşleme). Ağır anahtar türetme `KdbxKdf` arayüzünün arkasında: uygulamada Kotlin (AES-KDF `javax.crypto`, Argon2 başvuru uygulaması JNI ile), bilgisayardaki testlerde `pointycastle`.

**Teknoloji:** Dart, `crypto`, `pointycastle` 4.0.0 (yeni), `xml`, `dart:io` gzip; Kotlin, CMake, Pigeon `@TaskQueue`.

**Tasarım:** [`keepass-ice-aktarma.md`](keepass-ice-aktarma.md)

## Genel kısıtlar

- Sınırlar tasarımdaki tablodan: dosya 64 MiB, açılmış XML 64 MiB, Argon2 belleği ≤ 1 GiB, geçiş 1–1000, paralellik 1–64, AES-KDF turu 1–1.000.000.000, başlık alanı ve sözlük değeri ≤ 1 MiB, blok ≤ 64 MiB, anahtar dosyası ≤ 16 MiB.
- KDBX ana sürüm 2, 3 ve 4 okunur (2.x, 3.x okuyucusuyla; KeePassXC'in anahtar dosyası örnekleri 2.4). `.kdb` (imza `…65 FB 4B B5`) ve 2'den küçük sürüm `KdbxUnsupported`.
- Okuyucu yalnızca `KdbxException` alt türlerini fırlatır; başka istisna sızarsa hatadır.
- Hiçbir şey diske yazılmaz. Anahtar malzemesi `Uint8List`'tir ve işi bitince sıfırlanır.
- Kod adları İngilizce, yorumlar ve metinler Türkçe; commit biçimi `<tür>(<alan>): …`.
- Kontroller: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`.

## İnceleme odağı

1. **Boş parola + anahtar dosyası** (`test4_blankpass`): önce yalnız anahtar dosyası, sonra boş parola bileşeniyle ikinci deneme. Görev 7 sınar.
2. **Geçmişteki korumalı değerler iç akıştan pay alır**: geçmişi atlayan okuyucu sonraki kayıtların parolasını bozuk çıkarır. `test4.kdbx` (geçmişi bol) parolaları oracle'la karşılaştırılır. Görev 5 sınar.
3. **Yanlış anahtar bozuk dosya diye söylenmemeli**: her fixture yanlış parolayla `KdbxWrongKey` vermeli, KDBX3'te dolgu hatası da. Görev 4 sınar.
4. **gzip bombası ve dev KDF parametreleri**: elle kurulmuş başlıkla `KdbxTooHeavy`, bellek ayırmadan. Görev 2 ve 4 sınar.
5. **Büyük-küçük harf farklı iki özel alan** (`TestAttribute1`, `testattribute1`, `NewDatabase.kdbx`): ikisi de ayrı alan olarak gelir. Görev 6 sınar.

---

### Görev 1: Test dosyaları, `pointycastle`, `KdbxKdf` arayüzü ve testteki uygulaması

**Dosyalar:**
- Oluştur: `test/fixtures/kdbx/` (pykeepass `aec2566` ve KeePassXC `cd42236` commit'lerinden, değiştirilmeden), `test/fixtures/kdbx/KAYNAKLAR.md`
- Oluştur: `resources/scripts/kdbx-ornek.py` ve çıktısı `test/fixtures/kdbx/keykey_ornek.kdbx` (parola `keykey`)
- Oluştur: `lib/features/backup/data/import/kdbx/kdbx_kdf.dart`
- Oluştur: `test/helpers/dart_kdbx_kdf.dart`, `test/features/backup/kdbx/dart_kdbx_kdf_test.dart`
- Değiştir: `pubspec.yaml` (`pointycastle: ^4.0.0`)

**Arayüzler:**
- Üretir:
  ```dart
  enum Argon2Type { d, id }
  abstract interface class KdbxKdf {
    /// KeePass AES-KDF: [key] 32 bayt, [seed] 32 bayt; dönen değer SHA-256'dan geçmiş 32 bayt.
    Future<Uint8List> aesKdf({required Uint8List key, required Uint8List seed, required int rounds});
    /// 32 baytlık Argon2 çıktısı. Bellek ayrılamazsa KdbxOutOfMemory.
    Future<Uint8List> argon2({required Argon2Type type, required Uint8List password,
      required Uint8List salt, required int iterations, required int memoryKiB,
      required int parallelism, required int version, Uint8List? secret, Uint8List? associatedData});
  }
  ```
  `DartKdbxKdf implements KdbxKdf` (yalnızca test, `pointycastle` `Argon2BytesGenerator` ve `AESEngine`).

- [ ] **Adım 1:** Dosyaları indir: pykeepass `test3.kdbx/.key`, `test4*.kdbx`, `test4.key`, `test4_hex.key`, `test4_keyx.keyx`; KeePassXC `Format200/300/400`, `FileKeyBinary/Hex/Hashed/Xml/XmlV2/XmlV2HashFail` ve anahtarları, `NonAscii`, `Compressed`, `ProtectedStrings`, `NewDatabase`, `RecycleBinWithData`, `BrokenHeaderHash`. `KAYNAKLAR.md`: kaynak, commit, lisans (GPL-3.0; KeePassXC GPL-2.0/3.0), her dosyanın SHA-256'sı ve anahtarı (tablo: dosya, parola, anahtar dosyası, sürüm, şifre, KDF).
- [ ] **Adım 2:** `kdbx-ornek.py` (pykeepass 4.2.0) bir KDBX 4 dosyası yazar: `E-posta/İş` grubunda kayıt; `otp` alanı (`otpauth://totp/…`), KeePass 2 `TimeOtp-Secret-Base32` + `TimeOtp-Algorithm=HMAC-SHA-256` + `TimeOtp-Length=8` + `TimeOtp-Period=60`, eski `TOTP Seed`/`TOTP Settings=30;S` olan üç kayıt; `KP2A_URL` ve `KP2A_URL_1`; `androidapp://com.example` adresi; korumalı ve korumasız özel alan; yalnızca notu olan kayıt; hiçbir alanı olmayan kayıt; eki olan kayıt; çöp kutusuna atılmış kayıt; `{REF:P@I:…}` başvurusu. Betiğin çıktısı ve parola `KAYNAKLAR.md`'ye yazılır.
- [ ] **Adım 3: Testi yaz** `dart_kdbx_kdf_test.dart`: RFC 9106 §5.1 (Argon2d) ve §5.3 (Argon2id) vektörleri — parola 32×`01`, tuz 16×`02`, gizli 8×`03`, ek veri 12×`04`, m=32, t=3, p=4, sürüm 0x13; beklenen Argon2d `512b391b6f1162975371d30919734294f868e3be3984f3c1a13a4db9fabe4acb`, Argon2id `0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659`. AES-KDF: pykeepass'ın `test3.kdbx` için verdiği dönüştürülmüş anahtar Görev 4'te sınanır.
- [ ] **Adım 4:** Çalıştır, düşsün (`DartKdbxKdf` yok). Uygula, geçsin: `flutter test test/features/backup/kdbx/dart_kdbx_kdf_test.dart`.
- [ ] **Adım 5:** Commit `test(içe-aktarma): KeePass test dosyaları ve testteki anahtar türetme (#177)`.

### Görev 2: Hatalar, ikili okuyucu, dış başlık ve sözlük

**Dosyalar:**
- Oluştur: `lib/features/backup/data/import/kdbx/kdbx_exception.dart`, `kdbx_header.dart`
- Test: `test/features/backup/kdbx/kdbx_header_test.dart`

**Arayüzler:**
- Üretir:
  ```dart
  sealed class KdbxException implements Exception {}
  final class KdbxWrongKey, KdbxUnsupported(String what), KdbxTooHeavy, KdbxOutOfMemory, KdbxCorrupt, KdbxKeyFileCorrupt
  enum KdbxCipher { aes256, chaCha20, twofish }
  enum KdbxCompression { none, gzip }
  sealed class KdbxKdfParams; final class AesKdfParams(seed, rounds); final class Argon2Params(type, salt, iterations, memoryKiB, parallelism, version, secret, associatedData)
  final class KdbxHeader {
    final int majorVersion, minorVersion;
    final KdbxCipher cipher; final KdbxCompression compression;
    final Uint8List masterSeed, encryptionIv;
    final KdbxKdfParams kdf;
    // Yalnızca 2/3: protectedStreamKey, streamStartBytes, innerStreamId
    final Uint8List? protectedStreamKey, streamStartBytes; final int? innerStreamId;
    final Uint8List bytes; // başlığın ham baytları (özet ve HMAC için)
    static KdbxHeader parse(Uint8List file); // başlık sonu = bytes.length
  }
  static bool isKdbx(Uint8List bytes); // ilk 8 bayt KDBX imzası (sürüm denetimi yok)
  ```
- Argon2 belleği sözlükte bayt olarak durur; `memoryKiB = M ~/ 1024`, `M % 1024 != 0` bozuk.

- [ ] **Adım 1: Testleri yaz:** her fixture için `parse` doğru sürüm, şifre ve KDF türünü verir (`test3` 3.1 AES/AES-KDF, `test4` 4.0 ChaCha20/Argon2d, `test4_twofish` Twofish, `test4_argon2id` Argon2id, `test4_aeskdf` 4.0 AES-KDF, `FileKeyBinary` 2.4); `Format200` sürüm 2.0. `.kdb` imzası → `KdbxUnsupported`; sürüm 5 → `KdbxUnsupported`; bilinmeyen şifre UUID'si → `KdbxUnsupported`; ArcFour iç akış (3) değil 1 → `KdbxUnsupported`; Argon2 `M` = 2 GiB, `I` = 1001, `P` = 65, AES `R` = 10^9+1 → `KdbxTooHeavy`; 1 MiB'ı aşan alan uzunluğu → `KdbxCorrupt` (ayırmadan); her baytı kesilmiş başlık → yalnızca `KdbxException`.
- [ ] **Adım 2:** Düşsün. Uygula: alan kimlikleri 0 son, 2 şifre, 3 sıkıştırma, 4 ana tuz, 5 `TransformSeed`, 6 `TransformRounds`, 7 IV, 8 iç akış anahtarı, 9 `StreamStartBytes`, 10 iç akış kimliği, 11 KDF sözlüğü, 12 genel özel veri (yok sayılır), 1 yorum (yok sayılır). Sözlük: sürüm `0x01xx`, türler `04` u32, `05` u64, `08` bool, `0C` i32, `0D` i64, `18` dize, `42` bayt, `00` son. UUID'ler tasarımda.
- [ ] **Adım 3:** Geçsin. Commit `özellik(içe-aktarma): KDBX dış başlığı (#177)`.

### Görev 3: Bileşik anahtar ve anahtar dosyası

**Dosyalar:** Oluştur `kdbx/kdbx_key.dart`; test `kdbx_key_test.dart`.

**Arayüzler:**
- Üretir: `Uint8List keyFileKey(Uint8List file)` (32 bayt; bozuk 2.0 → `KdbxKeyFileCorrupt`; 16 MiB üstü → `KdbxCorrupt`), `Uint8List compositeKey({String? password, Uint8List? keyFileKey})` (en az biri dolu; `password: ''` boş parola bileşenidir).

- [ ] **Adım 1: Testleri yaz:** `FileKeyXml.key` 1.0 Base64, `FileKeyXmlV2.keyx` ve `test4_keyx.keyx` 2.0 onaltılık, `FileKeyBinary.key` 32 bayt, `FileKeyHex.key` ve `test4_hex.key` 64 onaltılık, `FileKeyHashed.key` SHA-256 sonuçları; `FileKeyXmlV2HashFail.keyx` → `KdbxKeyFileCorrupt`; XML ama `Version` 3.0 → dosyanın SHA-256'sı değil `KdbxKeyFileCorrupt`; `compositeKey(password: '')` ile `compositeKey(password: null, keyFileKey: k)` farklı. Beklenen değerler Görev 7'deki uçtan uca açılmayla doğrulanır; burada biçim kuralları.
- [ ] **Adım 2:** Düşsün, uygula, geçsin. Commit `özellik(içe-aktarma): KeePass anahtar dosyası (#177)`.

### Görev 4: Şifre çözme

**Dosyalar:** Oluştur `kdbx/kdbx_payload.dart`; test `kdbx_payload_test.dart`.

**Arayüzler:**
- Tüketir: `KdbxHeader`, `KdbxKdf`, `compositeKey`.
- Üretir:
  ```dart
  final class KdbxPayload {
    final Uint8List xml;           // açılmış XML baytları
    final int innerStreamId;       // 0, 2 (Salsa20), 3 (ChaCha20)
    final Uint8List innerStreamKey;
    final int binaryCount;         // KDBX4 iç başlıktaki ek sayısı
    void wipe();
  }
  Future<Uint8List> transformKey(KdbxHeader header, Uint8List composite, KdbxKdf kdf);
  KdbxPayload decryptPayload(Uint8List file, KdbxHeader header, Uint8List transformedKey);
  ```
- [ ] **Adım 1: Testleri yaz:** `transformKey` pykeepass'ın değerlerini verir: `NewDatabase.kdbx` (`a`) → `babcefd380208fa1e4d39b5e085047a9ad808bf27dc6c10c63ccf88f811b7581`, `RecycleBinWithData.kdbx` (`123`) → `108beef7db5c8c48772e319ff848416715b5b4596922bfe4e36d0034915f3b89`, `test4.kdbx` (`password` + `test4.key`) → `06e36d85bdb14fb2c7471e4fe2e9791cd82994c77bf101d25486ebbc104e675b`. Her desteklenen fixture doğru anahtarla `<?xml` ile başlayan XML verir; yanlış parolayla `KdbxWrongKey` (KDBX4 başlık HMAC'i, KDBX3 dolgu ya da `StreamStartBytes`); KDBX4'te şifreli veride tek bit değişince `KdbxCorrupt`; KDBX3'te blok özeti tutmayınca `KdbxCorrupt`; 64 MiB'ı aşan açılmış veri (elle kurulmuş gzip bombası) `KdbxTooHeavy` ve sınırı aşmadan durur.
- [ ] **Adım 2:** Düşsün. Uygula: ana anahtar `SHA-256(tuz ‖ dönüştürülmüş)`; KDBX4 HMAC taban anahtarı `SHA-512(tuz ‖ dönüştürülmüş ‖ 0x01)`, blok anahtarı `SHA-512(u64le(index) ‖ taban)`, başlık indeksi `2^64−1`, blok HMAC'i `u64le(index) ‖ i32le(boy) ‖ veri`; başlıktan sonra 32 bayt SHA-256, 32 bayt HMAC. KDBX3 blok: `u32 index ‖ 32 bayt özet ‖ i32 boy ‖ veri`, son blok boy 0. gzip `GZipCodec().decoder` parça parça, sayarak. İç başlık: 1 akış kimliği, 2 anahtar, 3 ek (sayılır, içeriği atılır), 0 son.
- [ ] **Adım 3:** Geçsin. Commit `özellik(içe-aktarma): KDBX şifre çözme (#177)`.

### Görev 5: XML ve korumalı değerler

**Dosyalar:** Oluştur `kdbx/kdbx_xml.dart`; test `kdbx_xml_test.dart`.

**Arayüzler:**
- Üretir:
  ```dart
  final class KdbxEntry {
    final String uuid;                       // Base64 UUID, büyük harf onaltılığa çevrilmiş (başvurular için)
    final List<String> groupPath;            // kök hariç
    final Map<String, ({String value, bool protected})> strings; // sırası korunur
    final int attachments;
  }
  final class KdbxDatabase {
    final List<KdbxEntry> entries;           // çöp kutusu hariç
    final int recycledEntries;
  }
  KdbxDatabase parseKdbxXml(KdbxPayload payload, {required Uint8List headerBytes, required int majorVersion});
  ```
- [ ] **Adım 1: Testleri yaz:** `test4.kdbx` kayıtları pykeepass'ınkilerle aynı (başlık, kullanıcı adı, parola, adres, not, grup yolu, ek sayısı; geçmişi bol `foobar_entry`'den sonraki kayıtların parolaları dahil); `RecycleBinWithData` 5 kayıt + `recycledEntries` 6; `ProtectedStrings` `TestProtected=ABC` korumalı, `TestUnprotected=DEF` korumasız; `NewDatabase` `TestAttribute1=b` ve `testattribute1=a` ayrı; `Format200` 1 kayıt, 2 ek; `BrokenHeaderHash` → `KdbxCorrupt`; geçmiş (`History`) kayıtları listeye girmez.
- [ ] **Adım 2:** Düşsün. Uygula: iç akış Salsa20 (`key = SHA-256(anahtar)`, IV `E830094B97205D2A`) ya da ChaCha20 (`h = SHA-512(anahtar)`, anahtar `h[0..32]`, nonce `h[32..44]`); belge sırasıyla `Protected="True"` taşıyan her öğenin Base64 değeri akışla XOR'lanır. `Meta/HeaderHash` varsa `SHA-256(headerBytes)` ile karşılaştırılır. Çöp kutusu `Meta/RecycleBinEnabled` + `RecycleBinUUID`.
- [ ] **Adım 3:** Geçsin. Commit `özellik(içe-aktarma): KDBX XML ve korumalı değerler (#177)`.

### Görev 6: Kayıt eşleme

**Dosyalar:**
- Oluştur `kdbx/kdbx_import.dart`; test `kdbx_import_test.dart`
- Değiştir `login_import.dart`: `LoginExportSource.keepassKdbx`; `LoginExport`'a `int withAttachments = 0`, `int inRecycleBin = 0`.

**Arayüzler:**
- Üretir: `LoginExport kdbxToLoginExport(KdbxDatabase db)`.
- [ ] **Adım 1: Testleri yaz** (`keykey_ornek.kdbx`, `test4.kdbx`, `NewDatabase.kdbx` üzerinden): klasör `E-posta/İş`; `otp` → aynı `otpauth://`; `TimeOtp-*` → `otpauth://totp/?secret=…&algorithm=SHA256&digits=8&period=60`; `TOTP Seed`+`30;S` → Steam; `NewDatabase` `TOTP Seed`+`30;6` → totp ve iki TOTP alanı özel alanlara girmez; `KP2A_URL*` adreslere eklenir, `androidapp://` alınmaz; korumalı özel alan `hidden: true`; `test4` `foobar_entry - Clone` kullanıcı adı `foobar`, `Clone with prefix and suffix` kullanıcı adı `domain\foobar2`; adsız kayıt adı kullanıcı adından (`blank_title`); yalnızca notlu kayıt `notes`'a; boş kayıt `skipped`'e; `withAttachments` ve `inRecycleBin` sayıları; `KPEX_` ile başlayan alan alınmaz.
- [ ] **Adım 2:** Düşsün, uygula, geçsin. Başvurular: `{REF:([TUPAN])@I:([0-9A-F]{32})}` büyük-küçük harf duyarsız, en çok 10 adım.
- [ ] **Adım 3:** Commit `özellik(içe-aktarma): KeePass kayıtlarının eşlenmesi (#177)`.

### Görev 7: Okuyucu cephesi ve bozuk girdi

**Dosyalar:** Oluştur `kdbx/kdbx_reader.dart`; test `kdbx_reader_test.dart`, `kdbx_fuzz_test.dart`.

**Arayüzler:**
- Üretir: `abstract final class KdbxReader { static const maxBytes = 64 * 1024 * 1024; static Future<LoginExport> open(Uint8List file, {String? password, Uint8List? keyFileKey, required KdbxKdf kdf}); }`. Boş parola kuralı tasarımdaki gibi (kutu boş = `password: null`).
- [ ] **Adım 1: Testleri yaz:** `KAYNAKLAR.md` tablosundaki her dosya açılır; `test4_blankpass` `password: null` + `test4.key` ile açılır (iki deneme); `Compressed` `password: null` ve anahtar dosyası yokken açılır (boş parola bileşeni); bozulma testi: her desteklenen küçük fixture'ın her baytı tek tek `^0xFF` → yalnızca `KdbxException` ya da başarı; 200 rastgele dosya (imzalı başlıkla) → yalnızca `KdbxException`.
- [ ] **Adım 2:** Düşsün, uygula, geçsin. Commit `özellik(içe-aktarma): KDBX okuyucu (#177)`.

### Görev 8: Telefonda anahtar türetme

**Dosyalar:**
- Oluştur `android/third_party/argon2/` (phc-winner-argon2 `20190702` etiketi: `include/argon2.h`, `src/{argon2.c,core.c,core.h,ref.c,thread.c,thread.h,encoding.c,encoding.h,blamka-round-ref.h}`, `src/blake2/*`, `LICENSE`) ve `README.md` (sürüm, commit, özet, lisans)
- Oluştur `android/app/src/main/cpp/CMakeLists.txt`, `android/app/src/main/cpp/argon2_jni.c`
- Değiştir `android/app/build.gradle.kts` (`externalNativeBuild { cmake { path = … } }`)
- Değiştir `pigeons/platform_api.dart` (`ImportCryptoApi`'ye `@TaskQueue(type: TaskQueueType.serialBackgroundThread)` ile `aesKdf`, `argon2`), üretilen dosyalar
- Değiştir `ImportCrypto.kt`; oluştur `lib/features/backup/data/import/kdbx/platform_kdbx_kdf.dart` (`kdbxKdfProvider`), `lib/app/bootstrap.dart` override
- Test: `integration_test/kdbx_kdf_test.dart`

**Arayüzler:**
- Pigeon: `Uint8List aesKdf(Uint8List key, Uint8List seed, int rounds)`, `Uint8List argon2(int type, Uint8List password, Uint8List salt, int iterations, int memoryKiB, int parallelism, int version, Uint8List? secret, Uint8List? associatedData)`; bellek hatası `PlatformException(code: 'out-of-memory')`, başka hata `'failed'`.
- JNI: `Java_io_github_aaudraa_keykey_Argon2Native_hash(...)` → `argon2_ctx`, `flags = ARGON2_FLAG_CLEAR_PASSWORD | ARGON2_FLAG_CLEAR_SECRET`, `threads = min(lanes, sysconf(_SC_NPROCESSORS_ONLN))`.
- [ ] **Adım 1: Cihaz testini yaz:** RFC 9106 vektörleri ve Görev 4'teki üç dönüştürülmüş anahtar `PlatformKdbxKdf` ile; `KdbxReader.open` bütün fixture'larla (fixture'lar `integration_test` içinden `rootBundle` yerine `dart:io` ile okunamaz: testte kullanılacak dosyalar `--dart-define` değil, `integration_test/fixtures` altında Dart sabiti olarak üretilir — `resources/scripts/kdbx-fixtures-dart.py` küçük dosyaları Base64 sabitlerine çevirir).
- [ ] **Adım 2:** Uygula. AES-KDF: `Cipher.getInstance("AES/ECB/NoPadding")`, 32 baytlık tamponla `update` döngüsü, sonunda SHA-256; kopyalar sıfırlanır.
- [ ] **Adım 3:** `flutter build apk --debug` geçer; Android 11 ve 17 emülatörlerinde `flutter test integration_test/kdbx_kdf_test.dart -d <cihaz>` geçer. Bir de KeePassXC varsayılanıyla (Argon2d, 64 MiB, 2 iş parçacığı, `keepassxc-cli db-create` 1 saniye) oluşturulmuş dosyanın açılma süresi ölçülür ve yol haritasına yazılır.
- [ ] **Adım 4:** Commit `özellik(android): Argon2 ve AES-KDF telefonda (#177)`.

### Görev 9: Ekranlar

**Dosyalar:**
- Oluştur `lib/features/backup/presentation/keepass_open_screen.dart`; test `test/features/backup/keepass_open_screen_test.dart`
- Değiştir `login_import_screen.dart` (`pickLoginExport`: 64 MiB ile seç, `KdbxHeader.isKdbx` ise ekrana git, değilse 10 MiB denetimi ve bugünkü okuyucu; kaynak adı `KeePass (KDBX)`; ek ve çöp kutusu bilgi kartları; `.kdbx` için silme hatırlatması yok), `router.dart` (`AppRoutes.keepassOpen`), `lib/l10n/app_tr.arb`, `app_en.arb`

**Arayüzler:**
- Tüketir: `KdbxReader.open`, `kdbxKdfProvider`, `keyFileKey`.
- [ ] **Adım 1: Widget testlerini yaz** (sahte `KdbxKdf` olarak `DartKdbxKdf`): `ProtectedStrings.kdbx` + `masterpw` → önizleme açılır; yanlış parola → kutunun altında hata, ekranda kalınır; anahtar dosyası seçilir ve kaldırılır; açılırken ilerleme metni; geri çıkınca dosya baytları sıfırlanır (sahte `DocumentFiles` aynı `Uint8List`'i verir, test sıfırlandığını görür); `.kdb` dosyası seçilince eski biçim mesajı; 64 MiB'ı aşan dosya `loginImportTooLarge`.
- [ ] **Adım 2:** Düşsün, uygula, geçsin. Metinler: `keepassOpenTitle` "KeePass dosyasını aç", `keepassPassword` "Ana parola", `keepassKeyFile` "Anahtar dosyası seç", `keepassKeyFileChosen` "Anahtar dosyası seçildi", `keepassOpen` "Aç", `keepassOpening` "Açılıyor… KeePass dosyaları parola denemelerini yavaşlatmak için bilerek yavaş açılır.", `keepassWrongKey` "Parola ya da anahtar dosyası yanlış. Dosya YubiKey ya da Windows hesabıyla korunuyorsa KeyKey onu açamaz.", `keepassUnsupported` "Bu KeePass dosyası desteklenmeyen bir ayar kullanıyor: {what}", `keepassOld` "Bu eski bir KeePass biçimi (KeePass 1). KeePass 2 ya da KeePassXC'de açıp yeniden kaydet.", `keepassTooHeavy` "Bu dosya telefonda açılamayacak kadar ağır ayarlanmış.", `keepassOutOfMemory` "Telefonun belleği bu dosyayı açmaya yetmedi.", `keepassCorrupt` "Dosya bozuk.", `keepassKeyFileCorrupt` "Anahtar dosyası bozuk.", `loginImportAttachments` "{count} kaydın ekleri alınmadı; KeyKey'de dosya eki yok.", `loginImportRecycleBin` "Çöp kutusundaki {count} kayıt alınmadı." ve İngilizceleri.
- [ ] **Adım 3:** Commit `özellik(içe-aktarma): KeePass dosyasını aç ekranı (#177)`.

### Görev 10: Belgeler ve sürüm

**Dosyalar:** `resources/docs/guvenlik-tasarimi.md` ("Parola içe aktarma" tablosu ve KeePass alt bölümü), `bagimliliklar.md`, `kullanim.md`, `resources/CHANGELOG.md`, `security-summary.md` gerekirse, `licenses_screen.dart` + `resources/assets/licenses/argon2.txt` + `pubspec.yaml` asset, `yol-haritasi.md`, `pubspec.yaml` sürüm `1.9.0+15`.

- [ ] **Adım 1:** Belgeler; lisanslar ekranı testi Argon2'yi bulur.
- [ ] **Adım 2:** Bütün kontroller ve `flutter test` yeşil. Commit `belge(içe-aktarma): KeePass içe aktarma belgeleri, 1.9.0 (#177)`.

### Görev 11: Gözden geçirme, PR, yayın

- [ ] Yeni bir alt ajanla bütün dalın incelemesi; bulgular düzeltilir.
- [ ] Entegrasyon testleri Android 11 ve 17'de; bir de arayüzden gerçek yol (dosya seç → parola → aç → ekle).
- [ ] PR `main`'e; bütün denetimler bittiğinde (`gh pr checks` bekleyen yok) `gh pr merge --merge --author-email 184309740+aaudraa@users.noreply.github.com`.
- [ ] `v1.9.0` etiketi, dağıtım onayı, yayın iş akışı yeşil (F-Droid karşılaştırması dahil), taslak yayımlanır; yol haritası güncellenir.
