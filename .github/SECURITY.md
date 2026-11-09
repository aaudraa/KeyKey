# Güvenlik Politikası

*English version below: [Security policy](#security-policy).*

## Güvenlik açığı bildirme

**Güvenlik açıklarını herkese açık issue olarak paylaşma.** Bunun yerine GitHub'ın [özel güvenlik bildirimi](https://github.com/aaudraa/KeyKey/security/advisories/new) formunu kullan.

Bildiriminde şunlar olursa açığı daha hızlı doğrulayabiliriz:

- Etkilenen bileşen ve sürüm ya da commit
- Açığı yeniden üretme adımları
- Olası etki: saldırganın neye erişebildiği ve hangi koşullar gerektiği

Bildirimine gerçek parola, 2FA anahtarı veya kasa dosyası ekleme.

## Süreç

KeyKey gönüllü olarak geliştirilen küçük bir proje, bu yüzden kesin bir yanıt süresi sözü veremiyoruz. Bildirimleri öncelikli olarak ele alıyor, düzeltme yayımlanana kadar ayrıntıları gizli tutuyoruz. İstersen yayımlanan güvenlik duyurusunda adınla teşekkür ederiz.

## Kapsam

**Kapsamda:** Bu repodaki kod, kasa ve yedek dosyası biçimi, kriptografik tasarım ve otomatik doldurma davranışı.

**Kapsam dışı:**

- Android'in veya üçüncü taraf kütüphanelerin kendi açıkları (bunları ilgili projeye bildir, KeyKey'i etkiliyorsa bize de haber ver)
- Kilidi açık, root edilmiş veya zararlı yazılım bulaşmış bir cihaz gerektiren senaryolar
- Cihaza fiziksel erişim ve ana parolanın bilinmesini gerektiren senaryolar

## Mevcut durum

KeyKey henüz yayımlanmadı ve **bağımsız bir güvenlik denetiminden geçmedi**. Kararlı bir sürüm çıkana kadar desteklenen bir sürüm yok; bildirimler `main` branch'ine göre değerlendirilir.

Tasarımın ayrıntıları [güvenlik tasarımı belgesinde](../resources/docs/guvenlik-tasarimi.md), projenin kendi denetimi [denetim belgesinde](../resources/docs/guvenlik-denetimi.md).

---

# Security policy

## Reporting a vulnerability

**Please don't report vulnerabilities as public issues.** Use GitHub's [private security advisory form](https://github.com/aaudraa/KeyKey/security/advisories/new) instead. Reports in English or Turkish are both fine.

These details help us confirm the issue faster:

- The affected component and the version or commit
- Steps to reproduce
- The impact: what an attacker can reach and under which conditions

Please don't attach real passwords, 2FA secrets or vault files.

## Process

KeyKey is a small project developed by volunteers, so we can't promise a fixed response time. Reports are handled first, and details stay private until a fix is published. If you like, we'll credit you by name in the published advisory.

## Scope

**In scope:** the code in this repository, the vault and backup file formats, the cryptographic design and autofill behaviour.

**Out of scope:**

- Vulnerabilities in Android or third-party libraries themselves (report them to that project, and tell us too if they affect KeyKey)
- Scenarios that require an unlocked, rooted or malware-infected device
- Scenarios that require physical access to the device and knowledge of the master password

## Current status

KeyKey hasn't been released yet and **hasn't had an independent security audit**. Until a stable release exists, no version is supported, and reports are assessed against the `main` branch.

The design is summarised in English in the [security design summary](../resources/docs/security-summary.md). The full design document and the project's own OWASP MASVS audit are in Turkish.
