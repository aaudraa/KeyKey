# Kart doldurma

Faz 15'in tasarımı. Hedef sürüm `1.5.0`. Takip: [#149](https://github.com/aaudraa/KeyKey/issues/149).

Proje sahibi kartı Faz 14'te "çok işime yarıyor, benimde olması gerekiyor" diye istedi ve 2026-11-19'da Faz 15'i başlattı. Aşağıdaki seçimler benim; proje sahibi soru sorulmadan ilerlenmesini istiyor, her seçimin gerekçesi yanında yazılı.

## Neden

1.4.0'dan beri kartlar kasada duruyor, ama ödeme formunda kullanmak için kart ekranını açıp numarayı, son kullanmayı ve güvenlik kodunu tek tek kopyalamak gerekiyor. Üç kopyalama, üç uygulama geçişi; her seferinde pano 30 saniye boyunca kart bilgisini taşıyor. Doldurma bunu tek seçime indirir ve panoyu hiç kullanmaz.

Bugünkü doldurma servisinin ödeme formlarında bir de hatası var: güvenlik kodu kutuları çoğunlukla gizli rakam kutusu (`numberPassword` ya da `type=password`) olduğu için servis onları parola sanıyor. Ödeme formunda "KeyKey ile doldur" çıkıyor, seçilen kaydın parolası güvenlik kodu kutusuna yazılabiliyor ve form gönderilince güvenlik kodunu parola diye kaydetmek öneriliyor.

## Hedefler

- Uygulamalarda ve Chrome'da ödeme formunun kart alanları tanınır: numara, kart sahibi, son kullanma (tek kutu ya da ayrı ay ve yıl, metin kutusu ya da açılır liste) ve güvenlik kodu.
- Kart alanında "KeyKey ile kart doldur" önerisi çıkar. Öneriye dokunulunca kasa açılır, kart listeden seçilir, form dolar.
- Güvenlik kodu kutusu artık parola sayılmaz: ödeme formunda parola önerisi ve parola kaydetme önerisi çıkmaz.
- Kart sahibinin adıyla, numarasıyla ya da markasıyla arama yapılabilir.

## Hedef olmayanlar

- **Formdan karta kaydetme.** Kullanıcı yeni bir kartı forma elle yazınca KeyKey kaydetmeyi önermez. Her ödemede çıkan bir öneri çoğu kullanıcıyı rahatsız eder ve kart ekranı zaten var. İstenirse ayrı bir iş.
- **Kart önerisini kapatma ayarı.** Servis kasaya dokunmadığı için kasada kart olup olmadığını bilmez; kartı olmayan kullanıcı da ödeme formunda öneriyi görür (Bitwarden ve KeePassDX'te de böyle). Ayar kasanın dışında, şifresiz bir yerde tutulmak zorunda kalırdı. Öneriye dokunan ve kartı olmayan kullanıcıya liste bunu söyler.
- **PIN doldurma.** Kart PIN'i çevrimiçi ödemede istenmez; hiçbir alana doldurulmaz.
- **Kartı listesiz doldurmak.** Girişteki "tek kesin eşleşme" kuralının kartta karşılığı yok: kart bir siteye ya da uygulamaya bağlı değil. Liste, kartın nereye gittiğini başlıkta gösteren son adımdır; tek kart olsa da açılır.
- **Adres, kimlik, telefon doldurma.** Kasada bu türler yok.

## Karşı hedefler

Bunlardan biri olursa iş çalışsa bile başarısızdır:

- Kart numarasının, güvenlik kodunun ya da son kullanma tarihinin servise, niyete, bildirime ya da günlüğe girmesi. Bildirim ve öneri değer taşımaz.
- Kartın yanlış kutuya yazılması: numaranın güvenlik kodu kutusuna, ayın yıl listesine.
- PIN'in herhangi bir kutuya yazılması.
- Bugün çalışan bir giriş formunun bozulması. Örneğin kart numarasıyla giriş yapılan bir banka formu (numara ve şifre kutusu) giriş formu olarak kalmalı.
- Güvenlik kodunun parola diye doldurulması ya da kaydedilmesi.

## Yaklaşımlar

### Öneri

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| 1. Tek öneri, "KeyKey ile doldur"; ekran forma bakıp parola ya da kart listesini açar | Öneri sayısı değişmez. | Hem e-posta hem kart kutusu olan bir ödeme formunda (misafir alışverişi) hangi listenin açılacağı belirsiz. Tek öneri bütün kutuları kapsadığından e-posta kutusunda da "kart" listesi açılabilir. |
| **2. Her tür için ayrı öneri** (seçilen) | Android bir öneriyi yalnızca odaktaki kutuya değer veren veri kümesinde gösterir. Giriş önerisi giriş kutularını, kart önerisi kart kutularını kapsar; ikisi kendi kutusunda çıkar. Ekran neyin istendiğini niyetin türünden bilir. | Servis iki kilitli öneri kurar; ekran iki tür istek taşır. |

**Seçim 2.** Kullanıcı hangi kutuya dokunduysa onun önerisini görür; karışık formda belirsizlik kalmaz.

### Alan tanıma

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| 1. Yalnızca geliştiricinin verdiği ipuçları (`creditCardNumber`, HTML `cc-number`) | Yanlış tanıma neredeyse yok. | Türkiye'deki ödeme formlarının çoğu ipucu vermiyor; Chrome'da `autocomplete` niteliği olmayan sayfalar tanınmaz. |
| **2. İpuçları, Chrome'un kendi tahmini ve sözcükler; sözcükler ancak iki ayrı kart alanı birlikte görülünce** (seçilen) | Chrome her kutu için kendi tahminini gönderiyor (`computed-autofill-hints`); sözcükler ipucusuz uygulamaları yakalar. "İki kanıt" kuralı, kart numarasıyla giriş yapılan banka formunu giriş formu olarak bırakır. | Sınıflandırıcı büyür; JVM testleriyle sınanır. |

**Seçim 2.**

## Tasarım

### Alan tanıma

Sınıflandırma Kotlin'deki `FieldClassifier`'da kalır. Yeni alan türleri: kart numarası, kart sahibi (tam ad, ad, soyad), son kullanma (tek kutu, ay, yıl) ve güvenlik kodu. Her kart alanı **güçlü** ya da **zayıf** kanıtla tanınır.

**Güçlü kanıt**, alanın kart olduğunu tek başına söyler:

1. Android ipuçları: `creditCardNumber`, `creditCardSecurityCode`, `creditCardExpirationDate`, `creditCardExpirationMonth`, `creditCardExpirationYear`. (`creditCardExpirationDay` tanınır ama doldurulmaz.)
2. HTML `autocomplete`: `cc-number`, `cc-name`, `cc-given-name`, `cc-family-name`, `cc-exp`, `cc-exp-month`, `cc-exp-year`, `cc-csc`. Chrome bu niteliği ipucu olarak da gönderiyor.
3. Chrome'un tahmini: HTML niteliklerinde `computed-autofill-hints`, yoksa `crowdsourcing-autofill-hints`, yoksa `ua-autofill-hints`. Değerler: `CREDIT_CARD_NUMBER`, `CREDIT_CARD_NAME_FULL`, `CREDIT_CARD_NAME_FIRST`, `CREDIT_CARD_NAME_LAST`, `CREDIT_CARD_EXP_MONTH`, `CREDIT_CARD_EXP_2_DIGIT_YEAR`, `CREDIT_CARD_EXP_4_DIGIT_YEAR`, `CREDIT_CARD_EXP_DATE_2_DIGIT_YEAR`, `CREDIT_CARD_EXP_DATE_4_DIGIT_YEAR`, `CREDIT_CARD_VERIFICATION_CODE`, `CREDIT_CARD_STANDALONE_VERIFICATION_CODE`. Kaynak Chromium'un `FormData.java` dosyası; aynı değerler Android System WebView'dan da gelir.
4. Güvenlik kodunun kendine özgü adları: `cvv`, `cvc`, `csc` (`cvv2`, `cvc2` de bunları içerir). Alanın kimliğinde, ipucu metninde ve HTML `name`, `id`, `placeholder`, `label` niteliklerinde aranır.

**Zayıf kanıt**, Türkçe ve İngilizce sözcüklerdir: "kart numarası", "card number", "son kullanma", "expiry", "AA/YY", "MM/YY", "kart sahibi", "name on card", "güvenlik kodu", "security code" ve benzerleri. Ayrıca bir ödeme formunda yalnızca "ay"/"month" ya da "yıl"/"year" diyen kutular son kullanma ayı ve yılı sayılır ("doğum" ya da "birth" geçmiyorsa). Sözcüklerin tam listesi kodda ve testlerinde.

**Ödeme formu kuralı.** Formda en az bir güçlü kanıt varsa ya da zayıf kanıtlar üç gruptan (numara, son kullanma, güvenlik kodu) en az ikisini kapsıyorsa form ödeme formudur ve bütün kart alanları kart sayılır. Değilse zayıf kanıtlar unutulur, alanlar bugünkü gibi giriş kurallarıyla tanınır. Kart sahibi kanıtı tek başına formu ödeme formu yapmaz.

Örnekler:

- Kart numarası (sözcük) ve şifre kutusu: ödeme formu değil. Numara kutusu bugünkü gibi kullanıcı adı sayılabilir, giriş önerisi çıkar.
- Kart numarası (sözcük), "AA/YY" ve gizli rakam kutusu "CVV": ödeme formu. Gizli kutu güvenlik kodudur, parola değil.
- Yalnızca "CVV" kutusu (kayıtlı kartın kodunu yeniden soran ekran): güçlü kanıt, ödeme formu. Kart önerisi çıkar, giriş önerisi ve parola kaydetme önerisi çıkmaz.

**Kart şifresi.** Ödeme formunda "kart şifresi" ya da "card PIN" diyen kutu kart PIN'i sayılır: hiçbir zaman doldurulmaz, parola sayılmaz ve parola diye kaydedilmez. Kart sahibi gibi o da formu tek başına ödeme formu yapmaz.

**Sıra.** Kart tanıma giriş tanımadan önce yapılır. Kart sayılan alan giriş türü alamaz; böylece gizli rakam kutusu olan güvenlik kodu parola sayılmaz. Giriş tanımanın kendi kuralları ve sözcükleri değişmez; değişen tek şey, kart sayılan alanların giriş tanımaya hiç girmemesidir. "Parola alanından önceki düz metin kutusu kullanıcı adıdır" tahmini kart alanlarını aday saymaz.

**Alan türleri.** Numara, kart sahibi ve güvenlik kodu yalnızca metin kutusu (`AUTOFILL_TYPE_TEXT`) olabilir. Son kullanma alanları metin kutusu, açılır liste (`AUTOFILL_TYPE_LIST`, HTML `select`) ya da tarih (`AUTOFILL_TYPE_DATE`) olabilir. Görünmeyen ve kapalı alanlar bugünkü gibi atlanır.

### Öneri

Servis yine kasaya dokunmaz. Formda giriş alanı varsa bugünkü "KeyKey ile doldur" önerisi giriş alanlarını, kart alanı varsa "KeyKey ile kart doldur" önerisi kart alanlarını kapsar. İkisi de değer taşımaz ve kimlik doğrulama ister. İki önerinin niyetleri eylemleriyle ayrılır (`…FILL_LOGIN`, `…FILL_CARD`); Android, yalnızca ek verisi farklı iki `PendingIntent`'i aynı sayar ve ikincisi birincisini iptal ederdi.

Satır içi öneride (klavye şeridi) her öneri sıradaki görünüm biçimini, biçimler biterse sonuncusunu kullanır.

Kaydetme önerisi (`SaveInfo`) yalnızca giriş alanlarından kurulur; kart alanları kaydetmeye girmez.

### Doldurma ekranı

Ekran kart isteğiyle açılınca kasa kilit ekranının altında "{hedef} için kart" yazar. Kasa açılınca çöp kutusunda olmayan kartlar listelenir. Sıralama ve arama kasa listesiyle aynıdır: arama ada, kart sahibine ve markaya bakar; numaraya ve güvenlik koduna bakmaz. Satırda kartın adı, marka ve son dört hane, son kullanma (geçmişse "Süresi geçmiş") görünür. Kasada kart yoksa liste bunu söyler ve kartın KeyKey'e eklenebileceğini yazar.

**Uyarı.** Güvenilen tarayıcıda sayfa `http` ile açılmışsa kart doldurulmadan önce uyarılır ve onay istenir: "Bağlantı şifresiz (http). Kart bilgileri ağda açık gider."

WebView uyarısı kartta verilmez. Girişte uyarının nedeni, bir siteye ait parolanın o siteyi taklit eden bir uygulamaya gitmesidir. Kart bir siteye ait değil; kullanıcı kartını hangi uygulamaya verdiğini başlıkta görür. Başlıkta WebView'ın bildirdiği alan adı değil, uygulamanın adı yazar (bugünkü `autofillTargetName` kuralı).

**Doldurma.** Kart seçilince değerler alınır, kasa kilitlenir ve değerler Kotlin'e verilir. Kotlin her kart alanı için değeri biçimler, bir `Dataset` kurar ve sisteme döndürür. Doldurulacak hiçbir alan kalmazsa ekran hiçbir şey doldurmadan kapanır. Bildirim kartın adını gösterir; adı boşsa marka ve son dört haneyi ("Visa •••• 1111 dolduruldu"). Son dört hane kasa listesinde ve fişlerde de görünen bilgidir.

### Değerlerin biçimi

Biçimleme Kotlin'de yapılır, çünkü alanın türünü, uzunluk sınırını ve seçeneklerini yalnızca Kotlin bilir. JVM testleriyle sınanır.

- **Numara:** yalnızca rakamlar. Formda birden çok numara kutusu varsa (dört kutuya bölünmüş numara) ve hepsinin uzunluk sınırı biliniyorsa numara sırayla sınırlara göre bölünür; bilinmiyorsa numaranın tamamı ilk kutuya yazılır.
- **Kart sahibi:** tam ad olduğu gibi. Ad ve soyad ayrıysa son boşluktan bölünür; tek sözcükse ad kutusuna yazılır.
- **Güvenlik kodu:** olduğu gibi.
- **Son kullanma, tek kutu (metin):** ay her zaman iki hane ve önde. Yıl iki hane; dört haneli yıl şu durumlarda yazılır: Chrome tahmini `…4_DIGIT_YEAR` diyor, ipucu metninde `YYYY` ya da `AAAA` geçiyor, ya da uzunluk sınırı 6 veya 7. Ayraç `/`; ipucu metninde başka bir ayraç (`-`, `.`, boşluk) varsa o kullanılır; uzunluk sınırı 4 ya da 6 ise ayraç yazılmaz.
- **Son kullanma, ay (metin):** iki hane, "01"–"12".
- **Son kullanma, yıl (metin):** dört hane; Chrome tahmini `…2_DIGIT_YEAR` diyorsa, ipucu metninde yalnızca `YY` ya da `AA` geçiyorsa veya uzunluk sınırı 2 ise iki hane.
- **Açılır liste:** seçeneklerin metnine bakılır. Ayda baştaki sayı ayla eşleşen seçenek ("1", "01", "01 - Ocak"), yoksa Türkçe ya da İngilizce ay adı ya da kısaltması ("Ocak", "Oca", "January", "Jan"). Yılda dört haneli ya da iki haneli yılla eşleşen seçenek. Eşleşen yoksa alan doldurulmaz.
- **Tarih alanı:** ayın 1'i, öğlen 12.00 UTC. Öğlen seçildi ki her saat diliminde aynı ay kalsın.
- **Uzunluk sınırı:** uygulamalarda `ViewNode.maxTextLength`, Chrome'da `maxlength` niteliği.
- Kartta değer yoksa (son kullanma girilmemiş, güvenlik kodu boş) o alan doldurulmaz.

### Kotlin ve Flutter arasındaki köprü

- `AutofillRequestInfo`'ya `forCard` eklenir: ekran kart isteğiyle mi açıldı.
- Yeni `AutofillApi.fillCard(CardFillValues values, String notice)`. `CardFillValues`: numara, kart sahibi, son kullanma ayı ve yılı (boş olabilir), güvenlik kodu. PIN köprüden hiç geçmez.
- Kotlin her çağrıyı isteğin türüne göre denetler: kart isteğinde `fill`, giriş isteğinde `fillCard` hiçbir şey doldurmadan ekranı kapatır.

### Testler

- JVM (`FieldClassifierTest` ve yeni `CardFillTest`): her kanıt kaynağı; ödeme formu kuralının iki yönü (banka giriş formu giriş kalır, CVV'li form ödeme formu olur); gizli rakam CVV parola sayılmaz; yalnızca CVV kutusu; doğum ayı ve yılı kart sayılmaz; değer biçimleri (tek kutu biçimleri, ayrı ay ve yıl, liste seçenekleri Türkçe ve İngilizce, bölünmüş numara, ad ve soyad).
- Flutter: kart listesi, arama, boş kasa, http uyarısı, doldurulan değerler, bildirim metni, kilitleme sırası, kart isteğinde giriş listesinin açılmaması.
- Örnek uygulamaya (`resources/test-apps/ornek-giris`) iki kart formu eklenir: ipuçlu (Android ipuçları, açılır ay ve yıl listesi) ve ipucusuz (sözcükler, tek "AA/YY" kutusu, gizli rakam CVV). Ayrıca bir WebView sayfasında `autocomplete`'li HTML kart formu.
- Emülatörde (Android 17 ve 11): üç formda öneri, kilit, liste, doldurma; formun gönderilince parola kaydetmeyi önermediği; mevcut giriş formunda giriş doldurmanın değişmediği. Doldurmadan sonra cihaz kaydı deneme değerleri için taranır.

### Belgeler

Güvenlik tasarımının "Otomatik doldurma" bölümüne "Kart doldurma" alt bölümü; kılavuza kart doldurma; değişiklik günlüğüne 1.5.0; yol haritasında Faz 15; mağaza açıklamasında doldurmanın kartları da kapsadığı.

## Uygulayana kalanlar

- Sözcük listelerinin tam içeriği (Türkçe ve İngilizce), testleriyle birlikte.
- Kart listesinin ekran düzeni: doldurma ekranının bugünkü cam çerçevesi ve satırları, kasa listesindeki kart satırının görünüşüyle.
- Arayüz metinlerinin son hali.
