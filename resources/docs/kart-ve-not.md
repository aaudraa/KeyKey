# Kart ve güvenli not

Faz 14'ün tasarımı. Hedef sürüm `1.4.0`.

Proje sahibi 2026-11-19'da "1.0 sonrası" listesindeki fikirlerin hepsini onayladı ve kartı özellikle istedi: "kart bilgilerini diyecektim çok işime yarıyor, benimde olması gerekiyor". Sıra ve aşağıdaki seçimler benim; her birinin gerekçesi yanında yazılı.

## Neden

Bugün KeyKey yalnızca parola ve 2FA kaydı tutuyor. Kart bilgisini saklamak isteyen kullanıcı ya bir parola kaydının notuna ya da özel alanlarına yazıyor ya da kasanın dışında, şifresiz bir yerde tutuyor. İlki zahmetli ve yanlış yerde: doldurma ekranı o kaydı parola diye öneriyor, son kullanma tarihi bilinmiyor, numara gruplanmadan duruyor. Wi-Fi parolası, kapı kodu, kurtarma kodları gibi bir siteye bağlı olmayan sırlar için de aynı durum geçerli.

Kart ve not, parola yöneticilerinin çoğunda (Bitwarden, 1Password, KeePassDX) temel kayıt türleri. Bitwarden'dan gelen kullanıcının kartları ve notları bugün içe aktarmada atlanıyor.

## Hedefler

- Kasa sekmesinde parola, kart ve not birlikte listelenir. Arama, favori, klasör, sıralama ve çöp kutusu üçü için de aynı çalışır.
- Kart kaydı: ad, kart sahibi, numara, son kullanma, güvenlik kodu, PIN ve not. Numara gruplanmış görünür, markası numaradan anlaşılır, süresi geçmişse ekranda yazar. Her alan tek dokunuşla kopyalanır.
- Not kaydı: ad ve metin.
- Kart ve notlar yedeğe, otomatik yedeğe, geri yüklemeye, Bitwarden'dan içe aktarmaya ve şifresiz dışa aktarmaya girer. KeyKey'den ayrılan kullanıcı kartlarını da yanında götürebilir.

## Hedef olmayanlar

- **Kart doldurma.** Android'in doldurma sistemi kart alanlarını tanıyor, ama doldurma tarafı ayrı ve büyük bir iş: Faz 15. Bu fazda doldurma ekranı yalnızca parola kayıtlarını okumaya devam eder.
- **Kimlik, adres, SSH anahtarı gibi başka türler.** İçe aktarmada atlanmaya devam ederler. Bu fazın düzeni yeni türü kolaylaştırır, ama türü eklemek ayrı karar.
- **Kart markasının logosu.** Markalar yazıyla gösterilir. Logolar marka hakkı olan görseller; lisans incelemesi gerekir ve uygulamaya bir şey katmaz.
- **Kartın internetten doğrulanması** (BIN sorgusu gibi). Marka numaranın ilk hanelerinden yerel olarak çıkarılır.

## Karşı hedefler

Bunlardan biri olursa iş çalışsa bile başarısızdır:

- Kart numarasının, güvenlik kodunun, PIN'in ya da not metninin şifresiz olarak diske, günlüğe ya da klavyenin sözlüğüne gitmesi.
- Eski bir yedeğin ya da 1.3.0 kasasının yeni sürümde açılamaması, veya parola kayıtlarının biçiminin değişmesi.
- Kart ya da not içeren bir yedeğin eski sürümde açılıp kartların sessizce kaybolması. Eski sürüm o yedeği açıkça reddetmeli.
- Doldurma ekranının kartı ya da notu parola diye önermesi.
- İçe aktarmada biçime uymayan bir kart değerinin sessizce atılması.

## Yaklaşımlar

### Kayıt modeli

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| **1. İki yeni kayıt türü: `card` ve `note`** (seçilen) | Parola (`login`) ve 2FA (`otp`) ile aynı düzen: her tür kendi katı biçimiyle okunur, `recordsOfType` ile yüklenir. Veritabanı şeması değişmez, `type` sütunu zaten metin. Parola kayıtlarına dokunulmaz. | Veritabanında şifresiz duran `type` sütunu kaç kart ve not olduğunu gösterir. |
| 2. Tek yeni tür (`item`), içinde `kind` alanı | Veritabanını ele geçiren kart ve notu ayırt edemez. | Her okuma iki biçimi tek kodda ayırmak zorunda; tür başına depo düzenine uymaz. Gizlediği bilgi, bugün de görünen parola ve 2FA sayısıyla aynı düzeyde. |
| 3. Kartı parola kaydının özel alanlarıyla tutmak (şablon) | Yeni biçim yok. | Doldurma ekranı kartı parola diye önerir; son kullanma, marka, numara gruplama ve Faz 15'teki kart doldurma yapılamaz. |

**Seçim 1.** Mevcut düzene en az sürprizle oturan yol bu. Kayıt sayısının türe göre görünmesi bugün parola ve 2FA için de geçerli ve tehdit modelinde kabul edilmiş bir ödün; [bilinen sınırlara](guvenlik-tasarimi.md#bilinen-sınırlar) kart ve not da eklenir. Veritabanı dosyası uygulamanın kendi klasöründe, şifreli kayıtlarla birlikte duruyor; sayıyı görebilen biri içeriği göremez.

### Arayüzdeki yeri

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| **1. Kasa sekmesinde ortak liste, türe göre süzgeç** (seçilen) | Sekmenin adı zaten "Kasa". Klasör, favori, arama ve çöp kutusu tek yerde. Bitwarden ve 1Password da böyle. | Liste ve çöp kutusu kodu üç türü birlikte taşıyacak biçimde genelleşir. |
| 2. Alt menüde ayrı bir "Kartlar" sekmesi | Kasa ekranına dokunulmaz. | Alt menüde Kasa, 2FA, Ayarlar ve + var; dördüncü sekme camı kalabalıklaştırır. Notlar için de ayrı bir yer gerekir. Klasörler bölünür. |

**Seçim 1.**

## Tasarım

### Kayıt biçimleri

İkisi de [kayıt biçimindeki](guvenlik-tasarimi.md#kayıt-biçimi) gibi şifrelenir: kayıt anahtarı, AD alanları `keykey/v1/record`, `vaultId`, kayıt kimliği ve tür. Okurken doğrulama parola kaydındaki kadar katıdır: bilinmeyen `version`, eksik alan, fazla alan veya yanlış tür reddedilir.

**Kart (`card`), sürüm 1:**

```json
{
  "version": 1,
  "name": "Maaş kartı",
  "cardholder": "AD SOYAD",
  "number": "4111111111111111",
  "expMonth": 12,
  "expYear": 2028,
  "securityCode": "123",
  "pin": "",
  "notes": "",
  "favorite": false,
  "folder": null,
  "trashedAt": null
}
```

| Alan | Kural |
|---|---|
| `number` | Yalnızca rakam, en çok 19 hane, boş olabilir. Boşluk ve tire yazarken atılır. |
| `expMonth`, `expYear` | İkisi birlikte `null` ya da ikisi birlikte dolu: ay 1-12, yıl 2000-2099. |
| `securityCode` | Yalnızca rakam, en çok 4 hane, boş olabilir. |
| `pin` | Yalnızca rakam, en çok 12 hane, boş olabilir. |
| `cardholder`, `name`, `notes`, `folder` | Serbest metin, parola kaydındaki gibi. |

Marka saklanmaz, her gösterimde numaranın ilk hanelerinden çıkarılır: Visa, Mastercard, American Express, Troy, Discover, JCB, UnionPay, Maestro, Diners Club; tanınmazsa marka yazılmaz. Böylece içe aktarılan yanlış bir marka bilgisi kayda girmez.

Numara Luhn denetiminden geçmezse ya da 12 haneden kısaysa düzenleme ekranı bir uyarı gösterir, ama kaydı engellemez. Kullanıcı numaranın bir kısmını bilerek saklamak isteyebilir.

**Not (`note`), sürüm 1:**

```json
{
  "version": 1,
  "name": "Ev Wi-Fi",
  "text": "...",
  "favorite": false,
  "folder": null,
  "trashedAt": null
}
```

`text` en çok 64 KiB (UTF-8). Daha uzun bir metin düzenleme ekranında girilemez, okurken reddedilir.

Kart ve notlar çöp kutusunda 30 gün kalır, parola kayıtlarıyla aynı kuralla kalıcı silinir.

### Liste

Kasa sekmesi üç türü tek listede gösterir.

```text
┌───────────────────────────────────────────┐
│ 🔍 12 kayıtta ara                          │
│ [Parolalar] [Kartlar] [Notlar] ★Favoriler │  ← tür çipleri yalnızca birden
│                                           │    fazla tür varsa
│ (🔑) GitHub              furky      ⧉     │
│ (💳) Maaş kartı                     ⧉     │
│      Visa •••• 4242 · 12/28               │
│ (📝) Ev Wi-Fi                             │
└───────────────────────────────────────────┘
```

- **Tür çipleri** favori ve klasör çiplerinin önünde durur ve yalnızca kasada birden fazla tür varsa görünür. Bugün yalnızca parolası olan kullanıcının ekranı değişmez.
- **Kart satırı:** ad (boşsa "Visa •••• 4242"), altında marka, son dört hane ve son kullanma. Süresi geçmişse son kullanma yerine "Süresi doldu" yazar. Sağdaki düğme kart numarasını kopyalar.
- **Not satırı:** yalnızca ad. Metnin ilk satırı listede gösterilmez: not çoğu zaman sırrın kendisidir ve liste ekranı omuz üstünden en çok görülen ekrandır.
- **Arama:** parolada bugünkü alanlar; kartta ad, kart sahibi, marka ve klasör; notta ad ve klasör. Bugünkü kural sürer: sır taşıyan alanlarda (parola, kart numarası, güvenlik kodu, not metni) arama yapılmaz.
- **Sıralama** (ad ya da son değişiklik), **favoriler** ve **klasörler** üç tür için ortak. Klasör listesi üç türün klasörlerinden çıkar.
- **Boş kasa** metni "parola" yerine "kayıt" der ve üç türü anar.

### Ekleme

Alttaki + panelinde "Parola" ve "2FA" satırlarının arasına "Kart" ve "Güvenli not" gelir. Paneli kasa kilitliyken açma kuralları parola satırıyla aynı.

### Ayrıntı ekranları

**Kart:**

```text
┌───────────────────────────────────┐
│ ╭───────────────────────────────╮ │
│ │ VISA                          │ │  ← kart görünümü: marka, gizli numara,
│ │ •••• •••• •••• 4242           │ │    son kullanma, kart sahibi
│ │ AD SOYAD              12/28   │ │
│ ╰───────────────────────────────╯ │
│ Kart numarası  •••• 4242   👁 ⧉   │
│ Son kullanma   12/28          ⧉   │
│ Güvenlik kodu  •••         👁 ⧉   │
│ PIN            ••••        👁 ⧉   │
│ Kart sahibi    AD SOYAD       ⧉   │
│ Notlar         ...                │
└───────────────────────────────────┘
```

- Numara, güvenlik kodu ve PIN gizli gelir; göz düğmesiyle açılır, parola alanındaki gibi.
- Kopyalanan her değer pano kuralından geçer ([Pano](guvenlik-tasarimi.md#pano)): hassas işaretiyle kopyalanır ve süre dolunca silinir. Kart sahibi ve son kullanma da aynı yoldan kopyalanır; kartın her parçası bir dolandırıcılık parçasıdır.
- Son kullanma ayın sonunda geçer. Süresi geçmiş kartta kart görünümünün altında "Süresi doldu" yazar.
- Menü, parola ayrıntısındakiyle aynı: düzenle, favori, çöp kutusuna taşı.

**Not:** ad başlıkta, metin seçilebilir olarak altında. Tek bir "Kopyala" düğmesi bütün metni hassas pano kuralıyla kopyalar.

### Düzenleme ekranları

**Kart:** ad, kart sahibi, kart numarası, son kullanma, güvenlik kodu, PIN, klasör, notlar.

- Kart numarası rakam klavyesiyle girilir ve yazarken gruplanır (çoğu kart 4-4-4-4, American Express 4-6-5). Marka kutunun yanında belirir.
- Son kullanma tek kutu, `AA/YY` biçiminde; eğik çizgi kendiliğinden gelir. Yıl iki haneyle girilir ve 2000'li yıllara çevrilir.
- Güvenlik kodu ve PIN gizli, rakam klavyesiyle girilir.
- Metin kutuları bugünkü kurallarla açılır: klavyenin öneri ve öğrenme özelliği kapalı.
- Kaydedilmemiş değişiklikle çıkarken parola düzenlemesindeki onay gelir.

**Not:** ad, metin (çok satırlı), klasör.

### Çöp kutusu

Kasanın çöp kutusu üç türü birlikte gösterir; geri alma ve kalıcı silme aynı.

### Yedek

- Yedeğe girebilen türler: `login`, `otp`, `card`, `note`, `settings`.
- **Yedek içeriğinin sürümü:** kart ya da not varsa 2, yoksa 1. Okuyucu ikisini de kabul eder; sürüm 1'de kart ve not türü reddedilir.
  - Neden her zaman 2 değil: kart ve notu olmayan bir kasanın yedeği 1.3.0'da açılmaya devam eder. Yeni sürümde bir sorun çıkar da eski sürüme dönmek gerekirse yedek işe yarar.
  - Kart içeren yedeği 1.3.0 "desteklenmeyen sürüm" diye reddeder; kartları sessizce atmaz.
- Kayıtlar veritabanındaki şifreli halleriyle taşınır, yedeğin dış katmanı kayıt türlerini zaten gizliyor.
- **Geri yükleme:** birleştirmede kart ve notlar da açık kasanın kayıt anahtarıyla yeniden şifrelenir; aynı kimlikte kayıt varsa yeni olan kalır.
- **Otomatik yedek ve hatırlatıcı:** kart ve not değişiklikleri de yedeği tetikler ve "son yedekten sonra değişen kayıt" sayılır.

### İçe aktarma

- **Bitwarden JSON:** tür 2 (güvenli not) not olur, tür 3 (kart) kart olur. Kart alanları: `cardholderName`, `number`, `expMonth`, `expYear`, `code`. Bitwarden'ın `brand` alanı yok sayılır. Notun klasörü ve favorisi alınır. Özel alanlar notun sonuna eklenir.
- **Bitwarden CSV:** `type` sütunu `note` olan satırlar not olur (bugün atlanıyor). Bitwarden CSV kart taşımaz.
- **Biçime uymayan kart değeri atılmaz:** numarada boşluk ve tireden başka karakter varsa, ay ya da yıl okunamıyorsa, güvenlik kodu 4 haneden uzunsa alan boş bırakılır ve ham değer etiketiyle birlikte kartın notuna eklenir. Önizleme ekranı bunu kartın yanında söyler.
- Önizleme ekranı kart ve notları kendi simgeleriyle, parolalarla aynı listede gösterir. Yinelenen işareti: kartta ad ve numara, notta ad ve metin kasadakiyle aynıysa.
- Kimlik ve SSH anahtarı atlanmaya ve sayılmaya devam eder.
- Ekranın adı "Parolaları içe aktar" yerine "İçe aktar" olur.

### Dışa aktarma

Bitwarden CSV kart taşıyamıyor. Bu yüzden şifresiz dışa aktarmaya ikinci bir biçim eklenir:

| Biçim | İçerik | Kimler okur |
|---|---|---|
| CSV (bugünkü) | Parolalar, 2FA bağlantıları ve notlar (`type=note`). Kartlar yazılmaz. | Bitwarden, KeePassXC ve CSV okuyan çoğu yönetici |
| **JSON (yeni)** | Hepsi: parolalar, 2FA, kartlar, notlar, klasörler | Bitwarden'ın şifresiz JSON biçimi; Bitwarden, KeePassXC ve Proton Pass içe alabiliyor |

- İki adımlı onay ve dosya kaydetme bugünkü gibi. Biçim, onaydan önceki pencerede seçilir. Kasada kart varsa CSV seçeneğinin altında "Kartlar bu biçimde yazılmaz" der.
- JSON, Bitwarden'ın şifresiz dışa aktarmasının alan adlarını kullanır (`encrypted: false`, `folders`, `items`; tür 1, 2, 3). 2FA bağlantıları CSV'deki kuralla yazılır.
- KeyKey kendi JSON'unu geri okuyabilmeli (gidiş-dönüş testi).

### Sürüm ve belgeler

- Sürüm `1.4.0+8`.
- [Güvenlik tasarımı](guvenlik-tasarimi.md): kart ve not biçimleri, yedek sürümü 2, içe ve dışa aktarma, bilinen sınırlar.
- Kılavuz, değişiklik günlüğü, iki dilde F-Droid sürüm notu, README'nin özellik listesi.

## Kurucunun kararına kalanlar

- Kod düzeni: parola deposundaki şifreleme, çözme ve çöp kutusu temizliği üç türde tekrar etmemeli. Ortak bir depo ya da yardımcı ve liste için ortak bir kayıt türü (ör. mühürlü `VaultEntry`) önerilir; adlar ve sınırlar planda belirlenir.
- Kart görünümünün çizimi (renk, köşe, cam) mevcut tasarım diline göre.
- Marka tanıma tablosunun tam aralıkları. Testlerde her markanın bilinen örnek numaraları kullanılır.

## Testler

- Kart ve not biçimleri: gidiş-dönüş, katı okuma, her alanın sınırı.
- Marka tanıma, Luhn, son kullanma biçimlendirme ve "süresi doldu" hesabı (ay sonu, yıl dönümü).
- Arama ve süzgeç: tür çipleri, kart alanları, not metninde arama yapılmaması.
- Depolar ve çöp kutusu süresi.
- Yedek: sürüm 1 ve 2 yazma kuralı, sürüm 1'de kart türünün reddi, birleştirmede kartların yeniden şifrelenmesi.
- İçe aktarma: Bitwarden JSON örneğine kart ve not eklenir (değerler sahte); CSV not satırları; biçime uymayan kart değerinin nota gitmesi.
- Dışa aktarma: JSON'un içe aktarmayla gidiş-dönüşü; CSV'de not satırları.
- Arayüz: + paneli, liste satırları, ayrıntı ve düzenleme ekranları, kaydedilmemiş değişiklik onayı.
- Cihaz testleri Android 17 ve 11 emülatörlerinde; kart ekleme, kopyalama, yedekleyip geri yükleme.
