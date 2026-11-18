# Yeni kurtarma anahtarı: uygulama planı

> Satır içi yürütülür (superpowers:executing-plans). Adımlar önce başarısız test, sonra kod düzenindedir.

**Hedef:** Kasa açıkken ana parolayla yeni bir kurtarma anahtarı üretmek; eski anahtar bu kasayı artık açmaz.

**Mimari:** Kripto çekirdeğine yalnızca kurtarma yuvasını yeniden saran bir işlem eklenir. Servis önce parolayı kilit ekranının yolundan doğrular, yeni yuvayı bellekte hazırlar, kullanıcının geri yazdığı anahtarla yuvayı açınca üst bilgiyi yazar. Arayüz kurulumdaki anahtar adımlarını ortak bileşene taşıyıp kullanır.

**Tasarım:** [`kurtarma-anahtari-yenileme.md`](kurtarma-anahtari-yenileme.md)

## Genel kısıtlar

- Üst bilgi biçimi değişmez (`version: 1`); yalnızca `slots.recovery` yenilenir.
- AD: `keykey/v1/wrap`, `vaultId`, `recovery`. KEK: `HKDF-Expand(anahtar, "keykey/v1/kek/recovery", 32)`.
- Diske yazılan üst bilgi doğrulama anındaki `session.header`'dan kurulur.
- Kasa açıkken dosya seçiciler `externalActivityGateProvider` kapısından geçer.
- Metinler Türkçe ve İngilizce; kod adları İngilizce.

## Gözden geçirmede dikkat

1. Doğrulama ile yazma arasında kasa kilitlenirse oturum ve kilit ekranının üst bilgisi tutarlı kalmalı (`_syncLockedHeader`).
2. Hazırlık ile doğrulama arasında parola değişirse (aynı ekranda olamaz ama servis buna açık) yeni parola yuvası geri alınmamalı.
3. Yanlış parolada hatalı deneme sayacı ve bekleme kilit ekranıyla aynı işlemeli; beklemedeyken parola denenmemeli.
4. Kurulum ekranının davranışı ortak bileşene taşınırken değişmemeli (kurulumda seçici kapıdan geçmez).
5. Yarım kalan akışta (geri, kilit, uygulama arka planda) diske bir şey yazılmamalı.

---

### Görev 1: Kripto

- Değiştir: `lib/core/crypto/vault_crypto.dart`, `lib/core/crypto/vault_header.dart`
- Test: `test/core/crypto/vault_crypto_test.dart`

Üretir: `final class NewRecoveryKey { final WrappedKey recoverySlot; final String recoveryKeyText; }`, `NewRecoveryKey VaultCrypto.newRecoveryKey(VaultHeader header, SecureKey vaultKey)`, `VaultHeader VaultHeader.withRecoverySlot(WrappedKey slot)`.

Testler ("kurtarma anahtarını yenileme" grubu): yeni anahtar aynı kasa anahtarını veriyor; eski anahtar yeni üst bilgide `WrongSecretException`; parola hâlâ açıyor; `vaultId`, `kdf`, parola yuvası aynı, kurtarma nonce'u farklı; iki yenileme farklı metin verir; metin `RecoveryKeyCodec` biçiminde (55 karakter).

### Görev 2: Servis

- Değiştir: `lib/core/vault/vault_service.dart`, `lib/core/vault/vault_session.dart`
- Test: `test/core/vault/vault_service_test.dart`

Üretir: `final class PendingRecoveryKey { final Uint8List vaultId; final WrappedKey recoverySlot; final String recoveryKeyText; }`, `Future<(PasswordAttempt, PendingRecoveryKey?)> VaultService.prepareNewRecoveryKey(VaultSession session, String currentPassword)`, `Future<void> VaultService.confirmNewRecoveryKey(VaultSession session, PendingRecoveryKey pending, String typed)`.

Testler: yanlış parola `PasswordRejected` döner, üst bilgi aynı, sayaç 1; beklemedeyken `PasswordMustWait` ve Argon2id çalışmaz; doğrulamada yanlış metin `InvalidRecoveryKeyException`, başka anahtar `WrongSecretException`, diske yazılmaz; doğru metin üst bilgiyi yazar, `session.header` güncellenir, diskten okunan üst bilgi yeni anahtarla açılır, eskisiyle açılmaz; hazırlıktan sonra parola değişirse yeni parola yuvası korunur; başka kasanın bekleyen yuvası (`vaultId` farklı) `StateError`.

### Görev 3: Denetleyici

- Değiştir: `lib/features/lock/application/vault_controller.dart`, `test/support/fake_vault_service.dart`
- Test: `test/features/lock/vault_controller_test.dart`

Üretir: `Future<(PasswordAttempt, PendingRecoveryKey?)> VaultController.prepareNewRecoveryKey(String currentPassword)`, `Future<void> VaultController.confirmNewRecoveryKey(PendingRecoveryKey pending, String typed)`. Kilit kuşağı değişirse hazırlık `PasswordInterrupted` döner; doğrulama kilitten sonra `VaultLockedException` atar ve yazarsa kilitli üst bilgiyi eşitler.

### Görev 4: Ortak anahtar adımları

- Oluştur: `lib/features/lock/presentation/recovery_key_steps.dart` (`RecoveryKeyShowStep`, `RecoveryKeyVerifyField`, `recoveryKeyMismatchHint`, `RecoveryKeyWarningCard`)
- Değiştir: `lib/features/onboarding/presentation/onboarding_screen.dart`

Davranış değişmez; kurulum testleri olduğu gibi geçer. Dosya kaydetme ve okuma bir `Future<T> Function<T>(Future<T> Function())` sarmalayıcısı alır: kurulumda doğrudan, kasa açıkken kapıdan.

### Görev 5: Ekran

- Oluştur: `lib/features/settings/presentation/new_recovery_key_screen.dart`
- Değiştir: `lib/app/router.dart`, `lib/features/settings/presentation/settings_screen.dart`, `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/settings/new_recovery_key_test.dart`

Testler: ayarlardan açılıyor; yanlış parola hata gösterir, ikinci adıma geçmez; doğru parola anahtarı gösterir; doğru yazınca not çıkar, servis yeni üst bilgiyi yazdı, otomatik yedek açıksa klasöre yazıldı; yanlış yazınca grup ipucu; geri çıkınca hiçbir şey yazılmadı; dosyaya kaydetme kapıdan geçer.

### Görev 6: Cihaz, belgeler, sürüm

- `integration_test/crypto_test.dart`: gerçek kasa, yenileme, yeni anahtarla açma, eskisiyle açılmama.
- `resources/docs/guvenlik-tasarimi.md` (Kurtarma anahtarı, bilinen sınır 5), `resources/docs/kullanim.md`, `resources/CHANGELOG.md`, `fastlane/metadata/android/{tr-TR,en-US}/changelogs/7.txt`, `pubspec.yaml` `1.3.0+7`, yol haritası.
- İki emülatörde bütün cihaz testleri; son gözden geçirme taze bir alt ajanla.
