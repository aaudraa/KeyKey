# Kart ve güvenli not: uygulama planı

> **Uygulayan için:** Bu plan görev görev uygulanır (superpowers:executing-plans). Adımlar `- [ ]` ile işaretlenir.

**Amaç:** Kasaya `card` ve `note` kayıt türlerini; listeyi, ekranları, yedeği, içe ve dışa aktarmayı eklemek.

**Mimari:** Kart ve not, parola kaydından bağımsız iki içerik sınıfıdır ve ortak bir genel depo (`VaultRecordRepository<C>`) ile genel bir denetleyiciden (`RecordsController<C>`) geçer. Parola deposu ve denetleyicisine dokunulmaz. Kasa ekranı ve çöp kutusu üç türü mühürlü `VaultEntry` üzerinden birlikte gösterir.

**Teknoloji:** Flutter, Riverpod 3, drift, libsodium (`sodium_sumo`), go_router.

**Tasarım:** [`kart-ve-not.md`](kart-ve-not.md). Plan tasarımdan yola çıkar; uygulayan ikisini birlikte okur.

## Genel kurallar

- Commit biçimi `<tür>(<alan>): <açıklama>`, Türkçe; türler yol haritasındaki tabloda. Her commit `Refs #146` taşır.
- Kod adları İngilizce, yorumlar Türkçe. Arayüz metinleri `lib/l10n/app_tr.arb` ve `app_en.arb`'ye birlikte girer, ardından `flutter gen-l10n`.
- Her görevin sonunda: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, ilgili testler.
- Şifresiz değerler günlüğe, istisna mesajına ya da `toString`'e girmez. İstisna mesajında yalnızca alan adı olabilir.
- Çözülmüş baytlar işi bitince `fillRange(0, length, 0)` ile sıfırlanır (parola deposundaki gibi).
- Kart ve not kayıt anahtarıyla şifrelenir (`session.records`), AD'de tür adı (`card`, `note`).
- Sürüm `1.4.0+8`.

## Gözden geçirmede bakılacaklar

Görevlerin testlerinin doğrudan sınamadığı ve kullanıcıyı en çok yakabilecek durumlar; her birinin testi sahibi olan göreve eklendi:

1. **Kasa kart düzenlenirken kilitlenir.** Kart ve not denetleyicileri kilitte belleği bırakmalı; süren bir yükleme kilitten sonra kayıtları geri getirmemeli (Görev 2).
2. **Kart numarası boşluk ve tireyle yapıştırılır** ("4111-1111 1111 1111"). Kutu rakamları alıp gruplamalı, hiçbir rakamı yutmamalı (Görev 4).
3. **Son kullanma yanlış girilir** ("13/28", "1/2", "00/30"). Kaydet düğmesi geçersiz ayı kabul etmemeli, hata kutunun altında yazmalı (Görev 4).
4. **Not 64 KiB sınırına çok baytlı harflerle yaklaşır.** Sınır karakter değil UTF-8 bayt; 33 000 "ğ" girilememeli, 32 000 girilebilmeli (Görev 1 ve 5).
5. **Kartlı bir yedek açık kasaya birleştirilir.** Kart ve not listeleri birleştirmeden sonra yenilenmeli; yeni kartlar uygulama yeniden açılmadan görünmeli (Görev 7).

---

## Dosya düzeni

| Dosya | Sorumluluk |
|---|---|
| `lib/features/vault/data/record_content.dart` (yeni) | `VaultItemContent` arayüzü, `InvalidRecordContentException`, katı JSON yardımcıları |
| `lib/features/vault/data/card_number.dart` (yeni) | Marka, Luhn, gruplama, `CardExpiry` |
| `lib/features/vault/data/card_content.dart` (yeni) | Kart içeriği ve biçimi |
| `lib/features/vault/data/note_content.dart` (yeni) | Not içeriği ve biçimi |
| `lib/features/vault/data/vault_record_repository.dart` (yeni) | Genel depo, `VaultRecord<C>` |
| `lib/features/vault/application/records_controller.dart` (yeni) | Genel denetleyici, kart ve not sağlayıcıları |
| `lib/features/vault/application/vault_entries.dart` (yeni) | `VaultKind`, `VaultEntry`, süzgeç, ortak liste sağlayıcısı |
| `lib/features/vault/presentation/vault_entry_tiles.dart` (yeni) | Liste satırları |
| `lib/features/vault/presentation/card_*.dart`, `note_*.dart` (yeni) | Ayrıntı, düzenleme, kart görünümü, giriş biçimleyicileri |
| `lib/app/ui/sensitive_selectable_text.dart` (yeni) | Yalnızca hassas kopyalamalı seçilebilir metin |
| `lib/features/backup/data/export/bitwarden_json_export.dart` (yeni) | Şifresiz JSON dışa aktarma |

---

### Görev 1: İçerik biçimleri ve kart yardımcıları

**Dosyalar:**
- Yeni: `lib/features/vault/data/record_content.dart`, `card_number.dart`, `card_content.dart`, `note_content.dart`
- Test: `test/features/vault/card_number_test.dart`, `card_content_test.dart`, `note_content_test.dart`

**Arayüzler (sonrakiler bunlara dayanır):**
- `final class InvalidRecordContentException implements Exception { const new(this.message); final String message; }`
- `abstract interface class VaultItemContent<Self extends VaultItemContent<Self>> { String get name; bool get favorite; String? get folder; DateTime? get trashedAt; bool get isTrashed; Uint8List toJsonBytes(); Self withFavorite(bool favorite); Self withTrashedAt(DateTime? trashedAt); }`
- `abstract final class StrictJson`: `decode(Uint8List)`, `object(Object?, Set<String> keys)`, `string`, `nullableString`, `boolean`, `nullableInt`, `nullableTime(Object?, String field)`. Hepsi `InvalidRecordContentException` fırlatır; `LoginContent`'teki yardımcıların aynısı.
- `enum CardBrand { visa, mastercard, amex, troy, discover, jcb, unionPay, maestro, diners }` ve `String get label` (`Visa`, `Mastercard`, `American Express`, `Troy`, `Discover`, `JCB`, `UnionPay`, `Maestro`, `Diners Club`)
- `CardBrand? detectCardBrand(String digits)`, `bool passesLuhn(String digits)`, `String groupCardNumber(String digits)`, `String lastFour(String digits)` (4 haneden kısaysa tamamı), `String? normalizeCardNumber(String raw)`
- `final class CardExpiry { new({required int month, required int year}); bool isExpiredAt(DateTime now); String format(); static CardExpiry? tryParse(String text); }`: ay 1-12 ve yıl 2000-2099 dışında `ArgumentError`
- `final class CardContent implements VaultItemContent<CardContent>`: `name`, `cardholder`, `number`, `CardExpiry? expiry`, `securityCode`, `pin`, `notes`, `favorite`, `folder`, `trashedAt`; `CardBrand? get brand`; `copyWith(...)` (`folder` ve `trashedAt` için `LoginContent`'teki `_keep` kuralı, `expiry` için de); `factory fromJsonBytes(Uint8List)`; sabitler `currentVersion = 1`, `maxNumberDigits = 19`, `maxSecurityCodeDigits = 4`, `maxPinDigits = 12`. Kurucu kurala uymayan numara, kod ya da PIN için `ArgumentError` fırlatır: okunamayacak bir kayıt yazılamaz.
- `final class NoteContent implements VaultItemContent<NoteContent>`: `name`, `text`, `favorite`, `folder`, `trashedAt`; `copyWith`, `fromJsonBytes`, `currentVersion = 1`, `maxTextBytes = 65536`. Kurucu sınırı aşan metinde `ArgumentError`.

**Marka tablosu** (en uzun önek önce denenir):

| Marka | Önekler |
|---|---|
| Troy | 9792 |
| Discover | 6011, 644-649, 65, 622126-622925 |
| UnionPay | 62, 81 (Discover'ın aralığı dışında) |
| Maestro | 5018, 5020, 5038, 5893, 6304, 6759, 6761, 6762, 6763 |
| Mastercard | 51-55, 2221-2720 |
| American Express | 34, 37 |
| Diners Club | 300-305, 3095, 36, 38, 39 |
| JCB | 3528-3589 |
| Visa | 4 |

Gruplama: American Express 4-6-5, 14 haneli Diners 4-6-4, diğerleri dörtlü. Ayraç tek boşluk.

- [ ] **Adım 1: Testleri yaz.**
  - `card_number_test.dart`: `detectCardBrand('4111111111111111') == CardBrand.visa`; `'5555555555554444'` ve `'2223000048400011'` Mastercard; `'378282246310005'` amex; `'9792000000000001'` troy; `'6011111111111117'` discover; `'6221260000000000'` discover, `'6200000000000005'` unionPay; `'3530111333300000'` jcb; `'30569309025904'` diners; `'6759649826438453'` maestro; `''` ve `'1234'` `null`. `passesLuhn('4111111111111111')` doğru, `'4111111111111112'` yanlış, `''` yanlış. `groupCardNumber('378282246310005') == '3782 822463 10005'`, `groupCardNumber('4111111111111111') == '4111 1111 1111 1111'`, `groupCardNumber('30569309025904') == '3056 930902 5904'`. `normalizeCardNumber('4111-1111 1111 1111') == '4111111111111111'`, `normalizeCardNumber('4111x') == null`, 20 hane `null`. `CardExpiry.tryParse('12/28')` ay 12 yıl 2028; `'13/28'`, `'00/30'`, `'1/2'` ve `'ab/cd'` `null`. `CardExpiry(month: 2, year: 2028).isExpiredAt(DateTime(2028, 2, 29, 23, 59))` yanlış, `DateTime(2028, 3, 1)` doğru; `CardExpiry(month: 12, year: 2028).isExpiredAt(DateTime(2029, 1, 1))` doğru. `format()` `'02/28'`.
  - `card_content_test.dart`: gidiş-dönüş (bütün alanlar dolu ve `expiry` `null`); `fromJsonBytes` bilinmeyen sürümü, eksik alanı, fazla alanı, rakam dışı numarayı, 20 haneli numarayı, 5 haneli güvenlik kodunu, 13 haneli PIN'i, yalnızca `expMonth`'u dolu olanı, `expMonth: 13`'ü ve `expYear: 1999`'u reddeder (`InvalidRecordContentException`); `toJsonBytes` alan adları tasarımdakiyle aynı (`expMonth`, `expYear`, `securityCode`); `withTrashedAt(null)` çöpten çıkarır; `brand` numaradan gelir. İstisna mesajı numarayı içermez.
  - `note_content_test.dart`: gidiş-dönüş; katı okuma; `'ğ' * 32000` kabul, `'ğ' * 33000` hem kurucuda (`ArgumentError`) hem okurken reddedilir.
- [ ] **Adım 2:** `flutter test test/features/vault/card_number_test.dart test/features/vault/card_content_test.dart test/features/vault/note_content_test.dart` → derleme hatasıyla düşer.
- [ ] **Adım 3:** Dört dosyayı yaz. `LoginContent`'e dokunma.
- [ ] **Adım 4:** Aynı komut → geçer.
- [ ] **Adım 5:** `özellik(kasa): kart ve not içerik biçimleri` commit'i.

### Görev 2: Genel depo ve denetleyici

**Dosyalar:**
- Yeni: `lib/features/vault/data/vault_record_repository.dart`, `lib/features/vault/application/records_controller.dart`
- Değişen: `lib/app/bootstrap.dart` (fabrikalar), `test/support/fake_vault_service.dart` (`loginRepositoryFactoryProvider`'ın yanına iki fabrika), `loginRepositoryFactoryProvider`'ı ezen her test ve entegrasyon testi: `test/features/autofill/autofill_screens_test.dart`, `test/features/backup/auto_backup_controller_test.dart`, `test/features/vault/logins_test.dart`, `integration_test/app_test.dart`, `biometric_test.dart`, `otp_flow_test.dart`
- Test: `test/features/vault/records_test.dart`

**Arayüzler:**
- Tüketir: Görev 1'in içerik sınıfları.
- Üretir:
  - `final class VaultRecord<C> { const new({required Uint8List id, required C content, required DateTime createdAt, required DateTime updatedAt}); }`, `typedef CardItem = VaultRecord<CardContent>; typedef NoteItem = VaultRecord<NoteContent>;`
  - `final class LoadedRecords<C> { items; unreadableCount }`
  - `class VaultRecordRepository<C extends VaultItemContent<C>>`: kurucu `{required VaultStore store, required VaultSession session, required SodiumSumo sodium, required String type, required C Function(Uint8List) decode, DateTime Function()? clock}`; `loadAll()`, `add(C)`, `update(VaultRecord<C>, C)`, `deletePermanently(VaultRecord<C>)`, `purgeExpiredTrash(List<VaultRecord<C>>)`. Çöp süresi `LoginRepository.trashRetention`. Sabitler `cardType = 'card'`, `noteType = 'note'`. Okunamayan kayıt (`CorruptedDataException` ya da `InvalidRecordContentException`) sayılır, listeyi düşürmez.
  - `VaultRecordRepository<CardContent> cardRepository({required VaultStore store, required VaultSession session, required SodiumSumo sodium})` ve aynı imzayla `noteRepository`.
  - `sealed class RecordsState<C>`: `RecordsLoading<C>`, `RecordsLoaded<C>({items, unreadableCount})` ve `trashed` getter'ı.
  - `class RecordsController<C extends VaultItemContent<C>> extends Notifier<RecordsState<C>>`: `add`, `addAll`, `update`, `setFavorite(item, {required bool favorite})`, `moveToTrash(item, DateTime now)`, `restore`, `restoreById(Uint8List)`, `deletePermanently`. Kilit ve nesil kuralı `LoginsController`'daki gibi.
  - `cardRepositoryFactoryProvider`, `noteRepositoryFactoryProvider` (`Provider<VaultRecordRepository<X> Function(VaultSession)>`, varsayılanı `UnimplementedError`), `cardsControllerProvider`, `notesControllerProvider`.
  - `VaultRecord<C>? findRecord<C>(RecordsState<C> state, String idHex)` (kimlik `loginIdHex` ile aynı onaltılık biçimde).

- [ ] **Adım 1: Testleri yaz** (`records_test.dart`, gerçek libsodium ve bellekte veritabanıyla, `logins_test.dart`'taki kurulum gibi):
  - `add` sonrası `loadAll` aynı içeriği döndürür; veritabanındaki `type` `card`; blob düz metinde numarayı içermez.
  - Kart deposunun yazdığı kayıt `noteRepository`'nin `loadAll`'unda görünmez, parola deposununkinde de görünmez.
  - Bozuk blob'lu kayıt `unreadableCount == 1` verir, diğerleri yüklenir.
  - 31 gün önce çöpe atılan kayıt `purgeExpiredTrash` ile silinir, 29 gün önceki kalır.
  - Denetleyici: `moveToTrash` ve `restoreById`; **kilit:** kasa kilitlenince durum `RecordsLoading`; kilitten önce başlayıp sonra biten yükleme durumu `RecordsLoaded` yapmaz.
- [ ] **Adım 2:** `flutter test test/features/vault/records_test.dart` → düşer.
- [ ] **Adım 3:** İki dosyayı yaz; `bootstrap.dart`'ta parola fabrikasının yanına `cardRepository`/`noteRepository` fabrikalarını, test desteğine ve listelenen testlere aynı ezmeleri ekle.
- [ ] **Adım 4:** `flutter test` (hepsi) → geçer.
- [ ] **Adım 5:** `özellik(kasa): kart ve not deposu ve denetleyicisi` commit'i.

### Görev 3: Ortak liste, arama ve süzgeç

**Dosyalar:**
- Yeni: `lib/features/vault/application/vault_entries.dart`
- Değişen: `lib/features/vault/application/login_search.dart` (`LoginFilter`'a `VaultKind? kind` ve `copyWith(..., VaultKind? kind, bool clearKind = false)`)
- Test: `test/features/vault/vault_entries_test.dart`

**Arayüzler:**
- `enum VaultKind { login, card, note }`
- `sealed class VaultEntry { Uint8List get id; VaultKind get kind; String get name; bool get favorite; String? get folder; bool get isTrashed; DateTime get updatedAt; }` ve `LoginEntry(LoginItem item)`, `CardEntry(CardItem item)`, `NoteEntry(NoteItem item)`
- `final class IndexedEntry { new(this.entry); final VaultEntry entry; final String searchText; }`
- `List<VaultEntry> filterEntries(List<IndexedEntry> entries, LoginFilter filter)`, `List<String> foldersOfEntries(Iterable<VaultEntry> entries)`
- `sealed class VaultEntriesState`: `VaultEntriesLoading`, `VaultEntriesLoaded({required List<IndexedEntry> indexed, required int unreadableCount})` ve `Set<VaultKind> get activeKinds`, `List<VaultEntry> get trashed`
- `final vaultEntriesProvider = Provider<VaultEntriesState>`: üç denetleyiciyi izler; biri yükleniyorsa `VaultEntriesLoading`; okunamayan sayılar toplanır.

Arama metni (`foldForSearch` ile): parola için bugünkü alanlar; kart için `name`, `cardholder`, `brand?.label`, `folder`; not için `name`, `folder`. Sıralama `sortLogins`'teki kuralla ad ya da `updatedAt`.

- [ ] **Adım 1: Testleri yaz:** `kind: VaultKind.card` yalnızca kartları döndürür; "visa" araması Visa kartını bulur; kart numarasının son dört hanesiyle ve not metnindeki bir kelimeyle arama sonuç vermez; "sifre" klasörü "Şifre"yi bulur (üç türde); çöptekiler süzgeçten çıkar, `trashed`'de görünür; `foldersOfEntries` üç türün klasörlerini tekilleştirip sıralar; `activeKinds` yalnızca parola varken `{login}`; sağlayıcı bir denetleyici yüklenirken `VaultEntriesLoading` verir.
- [ ] **Adım 2:** `flutter test test/features/vault/vault_entries_test.dart` → düşer.
- [ ] **Adım 3:** Yaz. `filterLogins` ve `foldersOf`'u kullanan başka yer kalmazsa sil (`grep -rn "filterLogins\|foldersOf(" lib`).
- [ ] **Adım 4:** `flutter test test/features/vault` → geçer.
- [ ] **Adım 5:** `özellik(kasa): parola, kart ve not için ortak liste` commit'i.

### Görev 4: Kart ekranları ve + paneli

**Dosyalar:**
- Yeni: `lib/features/vault/presentation/card_input_formatters.dart`, `card_face.dart`, `card_detail_screen.dart`, `card_edit_screen.dart`
- Değişen: `lib/app/secret_field.dart` (`TextInputType? keyboardType`; verilmezse bugünkü seçim), `lib/app/router.dart`, `lib/app/ui/add_panel.dart`, `lib/app/app_shell.dart`, `lib/app/last_saved.dart` (kart için kayıt anahtarı), `lib/l10n/app_tr.arb`, `app_en.arb`
- Test: `test/features/vault/card_screens_test.dart`, `test/app/ui/add_panel_test.dart` (varsa genişlet), router testleri

**Arayüzler:**
- `class CardNumberInputFormatter extends TextInputFormatter`: boşluk ve tire dışındaki rakam olmayanları atar, en çok 19 rakam, `groupCardNumber` ile gruplar, imleç `GroupedTextFormatter`'daki gibi yerleşir.
- `class ExpiryInputFormatter extends TextInputFormatter`: en çok 4 rakam, ikinci rakamdan sonra `/`.
- `CardFace({required CardContent content})`: marka (yazıyla), `•••• •••• •••• 4242`, kart sahibi, son kullanma; süresi geçmişse altında `cardExpired` metni.
- `CardDetailScreen({required String idHex})`, `CardEditScreen({String? idHex})` (`null` yeni kart).
- `AppRoutes.cardNew = '/kasa/yeni-kart'`, `cardItem(idHex) => '/kasa/kart/$idHex'`, `cardItemEdit(idHex) => '/kasa/kart/$idHex/duzenle'`. `resumeLocationFor` kart ayrıntısına da döner: `_vaultItem = RegExp(r'^/kasa/(kayit|kart|not)/[^/]+$')`.
- `AddChoice.card`, `AddChoice.note`; panelde "Parola" ile "2FA" arasında, `passwordEnabled` ile açılır.

Metinler (TR / EN): `addCard` Kart / Card, `addCardHint` Banka ve kredi kartları / Bank and credit cards, `cardName` Ad / Name, `cardholder` Kart sahibi / Cardholder, `cardNumber` Kart numarası / Card number, `cardExpiry` Son kullanma (AA/YY) / Expiry (MM/YY), `cardSecurityCode` Güvenlik kodu / Security code, `cardPin` PIN, `cardNotes` Notlar / Notes, `cardExpired` Süresi doldu / Expired, `cardNumberWarning` Bu numara bir kart numarasına benzemiyor. Yine de kaydedebilirsin. / This doesn't look like a card number. You can still save it., `cardExpiryInvalid` Ay 01-12, yıl iki haneli olmalı. / Month 01-12 and a two-digit year., `cardNotFound` Kart bulunamadı. / Card not found.

- [ ] **Adım 1: Testleri yaz:**
  - Biçimleyici: "4111-1111 1111 1111" yapıştırılınca metin `4111 1111 1111 1111`; "378282246310005" `3782 822463 10005`; 20. rakam yok sayılır; "1228" `12/28` olur.
  - Düzenleme: boş formla Kaydet kartı ekler ve ayrıntıya gider; "13/28" girilince `cardExpiryInvalid` görünür ve Kaydet kaydetmez; Luhn'dan geçmeyen numarada `cardNumberWarning` görünür ama kayıt yapılır; kaydedilmemiş değişiklikle geri dönünce parola düzenlemesindeki onay penceresi çıkar.
  - Ayrıntı: numara ve güvenlik kodu gizli gelir, göz düğmesiyle açılır; kopyala düğmesi hassas panoya rakamları gruplamadan yazar (`sensitiveClipboardProvider` sahtesiyle), kart sahibi ve son kullanma da aynı yoldan; süresi geçmiş kartta `cardExpired` görünür; menüden çöpe taşınır.
  - + paneli: "Kart" satırı `AppRoutes.cardNew`'a gider; kasa kilitliyken kapalı.
- [ ] **Adım 2:** `flutter test test/features/vault/card_screens_test.dart` → düşer.
- [ ] **Adım 3:** Yaz. Ayrıntı ekranı `LoginDetailScreen`'in iskeletini (iki kart, `_Field` benzeri satırlar, `KkMenuButton`) izler; düzenleme `LoginEditScreen`'in `_dirty` ve `PopScope` düzenini. Numara, güvenlik kodu ve PIN kutuları `SecretField(keyboardType: TextInputType.number, obscure: ...)`.
- [ ] **Adım 4:** `flutter gen-l10n` ve `flutter test` → geçer.
- [ ] **Adım 5:** `özellik(kasa): kart ekranları` commit'i.

### Görev 5: Not ekranları ve hassas seçim menüsü

**Dosyalar:**
- Yeni: `lib/app/ui/sensitive_selectable_text.dart`, `lib/features/vault/presentation/note_detail_screen.dart`, `note_edit_screen.dart`
- Değişen: `router.dart`, `add_panel.dart`, `app_shell.dart`, `last_saved.dart`, l10n
- Test: `test/features/vault/note_screens_test.dart`, `test/app/ui/sensitive_selectable_text_test.dart`

**Arayüzler:**
- `SensitiveSelectableText(String text, {TextStyle? style})`: `SelectableText` ve `contextMenuBuilder`; menüde yalnızca kopyala ve tümünü seç. Kopyala seçili parçayı `copySensitive` ile kopyalar, menüyü kapatır.
- `class Utf8LengthLimitingFormatter extends TextInputFormatter { const new(this.maxBytes); }`: yeni değer `maxBytes`'ı aşarsa eski değeri döndürür.
- `NoteDetailScreen({required String idHex})`, `NoteEditScreen({String? idHex})`; `AppRoutes.noteNew = '/kasa/yeni-not'`, `noteItem`, `noteItemEdit` (`/kasa/not/...`).
- Metinler: `addNote` Güvenli not / Secure note, `addNoteHint` Wi-Fi, kapı kodu, kurtarma kodları / Wi-Fi, door codes, recovery codes, `noteName` Ad / Name, `noteText` Metin / Text, `noteCopy` Metni kopyala / Copy text, `noteTooLong` Not çok uzun. / The note is too long., `noteNotFound` Not bulunamadı. / Note not found.

- [ ] **Adım 1: Testleri yaz:** kaydedilmemiş değişiklikle geri dönünce onay penceresi çıkar; seçim menüsünde "Kopyala" ve "Tümünü seç" dışında öğe yok; Kopyala hassas pano sahtesine seçili parçayı yazar ve sistem panosuna (`Clipboard`) bir şey yazılmaz; düzenleme 32 000 "ğ"yi kabul eder, 33 000'i kesmez ama yazdırmaz (değer eski kalır); ayrıntıdaki "Metni kopyala" bütün metni kopyalar; + paneli "Güvenli not" satırı `AppRoutes.noteNew`'a gider.
- [ ] **Adım 2:** `flutter test test/features/vault/note_screens_test.dart test/app/ui/sensitive_selectable_text_test.dart` → düşer.
- [ ] **Adım 3:** Yaz. Metin kutusu `SecretField(obscure: false, multiline: true, maxLines: 12, inputFormatters: [Utf8LengthLimitingFormatter(NoteContent.maxTextBytes)])`.
- [ ] **Adım 4:** `flutter gen-l10n` ve `flutter test` → geçer.
- [ ] **Adım 5:** `özellik(kasa): not ekranları` commit'i.

### Görev 6: Kasa listesi ve çöp kutusu

**Dosyalar:**
- Yeni: `lib/features/vault/presentation/vault_entry_tiles.dart` (`LoginTile`, `CardTile`, `NoteTile`; `_LoginTile` buraya taşınır)
- Değişen: `vault_screen.dart`, `trash_screen.dart`, l10n (`vaultEmpty`, arama sayısı, `vaultKindLogins` Parolalar / Passwords, `vaultKindCards` Kartlar / Cards, `vaultKindNotes` Notlar / Notes)
- Test: `test/features/vault/vault_screens_test.dart` (genişlet)

**Arayüzler:** Görev 3'ün `vaultEntriesProvider`, `filterEntries`, `foldersOfEntries`; Görev 4 ve 5'in rotaları.

- Tür çipleri `activeKinds.length > 1` ise favori ve klasör çiplerinin önünde; seçili tür kalmazsa süzgeç temizlenir (favori çipindeki kural).
- `CardTile`: başlık ad ya da `'${brand.label} •••• ${lastFour}'`; alt satır `'Visa •••• 4242 · 12/28'`, süresi geçmişse `· Süresi doldu`; sondaki kopyala düğmesi numarayı kopyalar (numara boşsa düğme yok).
- `NoteTile`: yalnızca ad; alt satır yok, kopyala düğmesi yok.
- Çöp kutusu üç türü `updatedAt`'e göre gösterir; geri alma ve kalıcı silme türün denetleyicisine gider; tümünü geri al ve boşalt üçüne birden uygulanır.
- Yeni metin `vaultEmpty`: "Henüz kayıt yok. Parola, kart ya da not eklemek için alttaki + düğmesine dokun." / "Nothing here yet. Tap + below to add a password, card or note."

- [ ] **Adım 1: Testleri yaz:** yalnızca parolalı kasada tür çipi yok; kart eklenince çipler görünür ve "Kartlar" yalnızca kartı bırakır; kart satırında son dört hane görünür, tam numara görünmez; not satırında metin görünmez; çöpteki kart ve not çöp ekranında görünür ve geri alınır; boş kasa yeni metni gösterir.
- [ ] **Adım 2:** `flutter test test/features/vault/vault_screens_test.dart` → yeni testler düşer.
- [ ] **Adım 3:** Yaz.
- [ ] **Adım 4:** `flutter test` → hepsi geçer.
- [ ] **Adım 5:** `özellik(kasa): kasa listesinde kart ve notlar` commit'i.

### Görev 7: Yedek, geri yükleme ve otomatik yedek

**Dosyalar:**
- Değişen: `lib/core/backup/backup_codec.dart`, `lib/core/crypto/crypto_exceptions.dart`, `lib/features/backup/application/restore_service.dart`, `backup_service.dart`, `auto_backup_controller.dart`, `lib/features/backup/presentation/restore_screen.dart`, l10n
- Test: `test/core/backup/backup_codec_test.dart`, `test/features/backup/restore_service_test.dart`, `auto_backup_controller_test.dart`, `restore_screen_test.dart`

**Arayüzler:**
- `BackupCodec.legacyRecordTypes = {'login', 'otp', 'settings'}`, `BackupCodec.recordTypes = {...legacyRecordTypes, 'card', 'note'}`, `BackupCodec.payloadVersion = 2`. `encode` kayıtların hepsi eski türdense içerik sürümü 1, değilse 2 yazar; bitmiş dosya `maxFileSize`'ı aşarsa `BackupTooLargeException` fırlatır.
- `final class NewerBackupException extends InvalidBackupException`: bilinmeyen dosya sürümü (`formatVersion`'dan büyük) ya da içerik sürümü (2'den büyük). `InvalidBackupException` gerekiyorsa `final` yerine `base` olur.
- `final class BackupTooLargeException implements Exception`. Elle yedek ve otomatik yedek bunu mevcut "yazılamadı" yolundan gösterir.
- `OpenedBackup` `cardCount` ve `noteCount` alır; `_verify` kartı `CardContent.fromJsonBytes`, notu `NoteContent.fromJsonBytes` ile doğrular (`InvalidRecordContentException` → `InvalidBackupException('Okunamayan kart kaydı.')` / `'Okunamayan not kaydı.'`).
- `BackupService.latestChange` türleri `{'login', 'otp', 'card', 'note'}`; `AutoBackupController` `cardsControllerProvider` ve `notesControllerProvider`'ı da dinler; `restore_screen.dart` birleştirmeden sonra `cardsControllerProvider` ve `notesControllerProvider`'ı da geçersiz kılar.
- Metinler: `restoreSummary` "{date} tarihli yedek: {logins} parola, {otps} 2FA hesabı, {cards} kart ve {notes} not." / "Backup from {date}: {logins} passwords, {otps} 2FA accounts, {cards} cards and {notes} notes.", `restoreNewerVersion` "Bu yedek KeyKey'in daha yeni bir sürümüyle alınmış. Uygulamayı güncelleyip yeniden dene." / "This backup was made with a newer version of KeyKey. Update the app and try again."

- [ ] **Adım 1: Testleri yaz:**
  - Codec: yalnızca parola ve 2FA kayıtlı yedeğin içerik sürümü 1 (çözülen JSON'da `version == 1`); bir kart eklenince 2; sürüm 1 içerikte `card` türü `InvalidBackupException`; sürüm 3 içerik ve sürüm 2 dosya `NewerBackupException`; 64 MiB'ı aşan kayıt listesi `BackupTooLargeException`. Sürüm 1 yedek örnek dosyası (varsa `test/fixtures` altındaki) hâlâ açılır.
  - Geri yükleme: kartlı yedek ilk kurulumda yazılır, `cardCount == 1`; birleştirmede kart açık kasanın anahtarıyla yeniden şifrelenir ve `cardRepository.loadAll()` onu okur; bozuk kart kaydı yedeği reddeder.
  - **Birleştirmeden sonra liste:** geri yükleme ekranı birleştirince `cardsControllerProvider` yeniden yüklenir ve yeni kart görünür.
  - Ekran: `NewerBackupException` `restoreNewerVersion`'ı gösterir.
  - Otomatik yedek: kart eklenince 5 sn sonra yedek yazılır.
- [ ] **Adım 2:** İlgili testler → düşer.
- [ ] **Adım 3:** Yaz.
- [ ] **Adım 4:** `flutter test` → geçer.
- [ ] **Adım 5:** `özellik(yedek): kart ve notlar yedekte` commit'i.

### Görev 8: Bitwarden'dan kart ve not içe aktarma

**Dosyalar:**
- Değişen: `lib/features/backup/data/import/login_import.dart`, `lib/features/backup/application/login_import_plan.dart`, `lib/features/backup/presentation/login_import_screen.dart`, l10n (`loginImportTitle` → "İçe aktar" / "Import")
- Test: `test/features/backup/import/login_import_test.dart`, `login_import_screen_test.dart`, Bitwarden JSON örneğine kart ve not eklenir (değerler sahte, test numarası `4111111111111111`)

**Arayüzler:**
- `final class ImportedCard { const new({required CardContent content, required bool adjusted}); }`, `adjusted` ham bir değer nota taşındıysa doğru.
- `LoginExport` `cards: List<ImportedCard>` ve `notes: List<NoteContent>` alır (varsayılan boş).
- `final class RecordImportCandidate<C> { const new({required C content, required bool duplicate, bool adjusted = false}); }`
- `LoginImportPlan` `cards: List<RecordImportCandidate<CardContent>>` ve `notes: List<RecordImportCandidate<NoteContent>>` alır; `planLoginImport(..., Iterable<CardItem> existingCards = const [], Iterable<NoteItem> existingNotes = const [])`. Yinelenen: kartta `name` ve `number`, notta `name` ve `text` aynı.

Kurallar (tasarımın "İçe aktarma" bölümü):
- Kart: `number` `normalizeCardNumber`'dan geçmezse boş, ham değer nota `<etiket>: <ham>` satırıyla; `expMonth` ve `expYear` metin ya da sayı olabilir, yıl iki haneyse 2000 eklenir, okunamazsa ya da yalnız biri varsa boş ve nota `<etiket>: <ay>/<yıl>`; `code` 4 haneden uzun ya da rakam dışıysa nota `<etiket>: <ham>`.
- Etiketler: veri katmanı dil bilmez. `LoginExportReader.read(Uint8List bytes, {ImportLabels labels = ImportLabels.english})`; `final class ImportLabels { const new({required String cardNumber, required String expiry, required String securityCode}); static const english = ImportLabels(cardNumber: 'Card number', expiry: 'Expiry', securityCode: 'Security code'); }`. İçe aktarma ekranı arayüz dilindekileri verir (`importLabelCardNumber` Kart numarası, `importLabelExpiry` Son kullanma, `importLabelSecurityCode` Güvenlik kodu).
- PIN: adı büyük-küçük harf duyarsız `PIN` olan, rakamdan oluşan, en çok 12 haneli ilk özel alan; kalan özel alanlar `ad: değer` satırlarıyla nota.
- Not: Bitwarden JSON tür 2 ve CSV `type=note`; özel alanlar nota eklenir; 64 KiB'ı aşan not atlanır ve `skipped`'e sayılır.

- [ ] **Adım 1: Testleri yaz:** JSON örneğinden 1 kart ve 1 not okunur, kimlik (tür 4) `skipped`'e sayılır; `expMonth: "1"`, `expYear: "28"` 01/2028 olur; `number: "4111 1111-1111 1111"` temizlenir; `number: "abc"` boş kalır, `adjusted` doğru ve not `Card number: abc` içerir; `PIN` adlı gizli alan PIN olur, başka bir alan nota gider; CSV'deki not satırı not olur; kasada aynı ad ve numaralı kart varsa aday `duplicate`; önizleme ekranı kartı kart simgesiyle gösterir, onaylanınca `cardsControllerProvider`'a eklenir.
- [ ] **Adım 2:** İlgili testler → düşer.
- [ ] **Adım 3:** Yaz.
- [ ] **Adım 4:** `flutter test` → geçer.
- [ ] **Adım 5:** `özellik(yedek): Bitwarden'dan kart ve not içe aktarma` commit'i.

### Görev 9: Şifresiz dışa aktarmada JSON ve notlar

**Dosyalar:**
- Yeni: `lib/features/backup/data/export/bitwarden_json_export.dart`
- Değişen: `bitwarden_csv_export.dart` (`notes` parametresi), `lib/features/backup/presentation/plaintext_export.dart`, l10n
- Test: `test/features/backup/export/bitwarden_json_export_test.dart`, `bitwarden_csv_export_test.dart`, `test/features/backup/plaintext_export_test.dart`

**Arayüzler:**
- `BitwardenCsvExport.build({required Iterable<LoginItem> logins, required Iterable<OtpItem> otps, Iterable<NoteItem> notes = const []})`: not satırı `folder, favorite, 'note', name, text`, kalan sütunlar boş.
- `abstract final class BitwardenJsonExport { static String build({required Iterable<LoginItem> logins, required Iterable<OtpItem> otps, required Iterable<CardItem> cards, required Iterable<NoteItem> notes}); }`: kök `{"encrypted": false, "folders": [...], "items": [...]}`. Öğe kimliği kayıt kimliğinin UUID biçimi (8-4-4-4-12). Klasör kimliği sıradan üretilir (`00000000-0000-4000-8000-000000000001` ...). Parola tür 1 (`login.uris`, `username`, `password`, `totp`; özel alanlar `type` 0 ya da 1), not tür 2 (`secureNote: {"type": 0}`, metin `notes`'ta), kart tür 3 (`card.cardholderName`, `brand` etiketi ya da `null`, `number`, `expMonth` ve `expYear` metin, `code`), PIN `{"name": "PIN", "value": ..., "type": 1, "linkedId": null}`. Bağlı olmayan 2FA hesapları CSV'deki kuralla ayrı parola öğesi. Çöptekiler yazılmaz.
- `enum ExportFormat { csv, json }`; `Future<ExportFormat?> showExportFormatChoice(BuildContext context, {required bool hasCards})` uyarıdan önce açılır; `plaintextExportFileName(now, {required String prefix, String extension = 'csv'})`; JSON için MIME `application/json`.
- Metinler: `exportFormatTitle` Biçim seç / Choose a format, `exportFormatCsv` CSV, `exportFormatCsvHint` Bitwarden, KeePassXC ve çoğu yönetici okur. / Read by Bitwarden, KeePassXC and most managers., `exportFormatCsvNoCards` Kartlar bu biçimde yazılmaz. / Cards are not included in this format., `exportFormatJson` JSON, `exportFormatJsonHint` Kartlar dahil her şey. Bitwarden'ın biçimi. / Everything, cards included. Bitwarden's format.

- [ ] **Adım 1: Testleri yaz:** **gidiş-dönüş:** iki parola (biri 2FA'ya bağlı), bir bağlı olmayan 2FA, PIN'li bir kart ve bir not JSON'a yazılıp `LoginExportReader.read` ile okununca parola alanları, `totp`, kartın bütün alanları (PIN dahil), notun metni, klasör ve favoriler aynı gelir; çöpteki kart yazılmaz; CSV'de not `type=note` satırı olur ve CSV okuyucusu onu not olarak geri okur; biçim penceresinde kart varsa `exportFormatCsvNoCards` görünür; JSON seçilince kaydedilen dosya adı `.json` ile biter.
- [ ] **Adım 2:** İlgili testler → düşer.
- [ ] **Adım 3:** Yaz.
- [ ] **Adım 4:** `flutter test` → geçer.
- [ ] **Adım 5:** `özellik(yedek): şifresiz JSON dışa aktarma` commit'i.

### Görev 10: Belgeler ve sürüm

**Dosyalar:** `resources/docs/guvenlik-tasarimi.md` (Kayıt biçimi altına "Kart kaydının içeriği" ve "Not kaydının içeriği"; Yedek biçimi: türler ve içerik sürümü 2, boyut denetimi, daha yeni sürüm hatası; Parola içe aktarma: kart ve not kuralları; Düz metin dışa aktarma: JSON; Bilinen sınırlar: türe göre kayıt sayısı), `resources/docs/kullanim.md`, `resources/CHANGELOG.md` (1.4.0; 1.3.0'ın kartlı yedeği "bozuk" diye göstereceği uyarısı), `fastlane/metadata/android/tr-TR/changelogs/8.txt` ve `en-US/changelogs/8.txt`, `README.md` (özellikler), `pubspec.yaml` (`version: 1.4.0+8`), `resources/yol-haritasi.md` (Faz 14 bölümü ve durum).

- [ ] **Adım 1:** Belgeleri yaz; güvenlik tasarımındaki biçimler `CardContent.toJsonBytes` çıktısıyla alan alan aynı olmalı.
- [ ] **Adım 2:** `flutter test` (sürüm testi varsa) → geçer.
- [ ] **Adım 3:** `belge(kasa): kart ve not belgeleri, sürüm 1.4.0` commit'i.

### Görev 11: Cihaz testleri ve son gözden geçirme

**Dosyalar:** `integration_test/card_note_test.dart` (yeni)

- [ ] **Adım 1:** Entegrasyon testi: + panelinden kart ekle (numara, son kullanma, güvenlik kodu), listede son dört hane, ayrıntıda numarayı kopyala, not ekle, ikisini çöpe at ve geri al, yedek al ve yeni kasaya geri yükleyince kart ve not gelir.
- [ ] **Adım 2:** Android 17 ve 11 emülatörlerinde bütün entegrasyon testleri (`flutter test integration_test -d <cihaz>`, her parça 10 dakikanın altında, emülatör `-memory 2048 -gpu host`).
- [ ] **Adım 3:** Taze bir gözden geçirici bütün dalı tasarım ve bu planla karşılaştırır; bulgular düzeltilir.
- [ ] **Adım 4:** Faz PR'ı, CI yeşilse birleştirme, `v1.4.0` etiketi ve yayın.
