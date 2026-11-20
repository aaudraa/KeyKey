# KeyKey Security Design: Summary in English

KeyKey is an open-source password manager and TOTP/HOTP authenticator for Android with no account and no server of its own, written in Flutter with small Kotlin parts. Since 1.8.0 it can sync the vault, end-to-end encrypted, through a WebDAV folder the user provides. It needs Android 11 (API 30) or newer.

This page summarises the security design for reviewers who don't read Turkish. The full and authoritative design is the Turkish [security design document](guvenlik-tasarimi.md); the [self-audit against OWASP MASVS](guvenlik-denetimi.md) is also in Turkish. Section links below point into those documents. If this summary and the Turkish document disagree, the Turkish document wins, and the disagreement is a bug worth reporting.

**Status (2026-11-16, `v1.0.0`):** Released. Not independently audited. The project's own MASVS audit is complete.

## Goals and non-goals

KeyKey tries to make sure that:

- someone who obtains the vault file or a backup can't read its contents if the master password is strong;
- someone with the file can't see which sites the user has accounts on;
- tampering with the file is detected, and one record's ciphertext can't be substituted for another's.

KeyKey does not protect against:

- a rooted or malware-infected device while the vault is open;
- a weak master password;
- losing both the master password and the recovery key. There is deliberately no back door.

**Principle:** we don't implement our own vault cryptography. All vault primitives come from [libsodium](https://libsodium.org) 1.0.22; KeyKey only composes them.

**Network:** versions 1.0-1.5 had no `INTERNET` permission. Since 1.6.0 there is the breach check the user starts in the password report: k-anonymity against Have I Been Pwned's Pwned Passwords API, sending only the first 5 hex characters of each password's SHA-1 hash, over HTTPS only. Since 1.8.0 there is also [sync](#sync), only if the user turns it on, only with the WebDAV server the user enters, and only end-to-end encrypted files. Backups, autofill and the clipboard never go online. All network code lives in two files (`lib/core/network/pwned_passwords_client.dart` and `lib/core/network/webdav_client.dart`), and a test fails the build if network APIs appear anywhere else in the Dart or Kotlin sources; CI also checks the release APK's permission list. [Sızıntı kontrolü](guvenlik-tasarimi.md#sızıntı-kontrolü).

## Threat model (condensed)

Full table: [Tehdit modeli](guvenlik-tasarimi.md#tehdit-modeli).

| Attacker | Result |
|---|---|
| Finds or steals the locked phone and images the disk | Protected: the key is derived from the master password and never stored |
| Has the unlocked phone briefly while KeyKey is locked | Protected if the password is strong: master password or fingerprint required, growing delays after wrong attempts, enrolling a new fingerprint disables fingerprint unlock |
| Has the unlocked phone while KeyKey is open | Partly: visible entries can be read. KeyKey locks when backgrounded or after 5 minutes without touch; changing the password and plaintext export ask for authentication again |
| Obtains a backup file (e.g. a compromised cloud account) | Protected if the password is strong; old backups open with the old password |
| Can write to the vault file on disk | Can't read it, and modified records don't decrypt; but rollback and deletion aren't detected |
| Malicious app on the device without special permissions | Protected by app sandboxing; only the launcher activity and the system-bound autofill service are exported |
| Network attacker (same Wi-Fi, captive portal, ISP) on the breach check or sync | Protected: no password in the traffic, only 5-character hash prefixes; HTTPS with system CAs only (Dart's client reads Android's system CA store itself and does not load user-added CAs), non-HTTPS addresses refused, redirects not followed; a malformed response such as a captive portal's HTML fails the check instead of reporting "not seen". The attacker can block the check |
| Have I Been Pwned or Cloudflare in front of it | Partly: sees the IP address, the prefixes asked for and the time; the set of prefixes can fingerprint a vault; a false "not seen" answer can't be detected |
| The WebDAV server, or whoever controls it | Protected if the password is strong: sees file names (device IDs), sizes, modification times and the IP address, and can delete, withhold or roll back files, which only delays changes; can guess the master password offline as with a backup |
| An unused phone's sync file or the server's file history | **Not protected**: opens with the old password and yields the vault key, which also opens later files; a password change is not a revocation |
| Stolen phone with the vault unlocked and sync on | Partly: it keeps syncing until its app password is revoked on the server |
| Malicious autofill target (fake app, fake site, app with a WebView) | Largely protected: signing-certificate check, trusted-browser list, warnings |
| App with overlay permission (tapjacking) | Protected: overlays hidden on Android 12+, obscured touches dropped on Android 11 |
| App with accessibility permission | Protected on Android 14+; **not protected on Android 11-13** |
| Malicious keyboard | **Not protected** |
| Root or malware while the vault is open | **Not protected** |

Out of scope: coercion, shoulder surfing, OS vulnerabilities and hardware attacks.

## Primitives

| Purpose | Algorithm |
|---|---|
| Password to key | Argon2id (`crypto_pwhash`), 16-byte salt, 32-byte output |
| Encryption | XChaCha20-Poly1305 IETF: 32-byte key, 24-byte random nonce, 16-byte tag |
| Subkeys | HKDF-SHA256, expand step only (the vault key is already uniformly random) |
| Recovery key checksum | BLAKE2b |
| Randomness | libsodium `randombytes`, which uses the OS CSPRNG |

The 24-byte nonce is long enough to pick at random, so no counters are kept. `dart:math` `Random` isn't used anywhere.

## Key hierarchy

```text
Master password ── Argon2id ──────────► password KEK ──┐
Recovery key ── HKDF ─────────────────► recovery KEK ──┼─ wraps ─► vault key (random, 32 bytes)
Fingerprint ── Android Keystore AES-GCM ───────────────┘                │
                                                                   HKDF-SHA256
                                                          ┌─────────────┴─────────────┐
                                                     record key                    OTP key
                                                 "keykey/v1/records"           "keykey/v1/otp"
```

- The vault key never changes. Changing the password only rewraps it; records aren't re-encrypted. The consequences are in [Known limitations](#known-limitations) item 5.
- The vault key and subkeys live in libsodium's protected memory (`SecureKey`) and are disposed on lock.

**Argon2id parameters.** The floor is 64 MiB and 3 passes; the ceiling is 1 GiB and 32 passes, and files above it are rejected so a crafted file can't exhaust memory. Parallelism is always 1. When the vault is created, a calibration run raises the pass count (never the memory) towards a 1 second target, up to 12 passes. On a Galaxy S20 FE, 12 passes take 864 ms. The parameters are stored in the header. The password is used as raw UTF-8 bytes without Unicode normalisation. Details: [Argon2id parametreleri](guvenlik-tasarimi.md#argon2id-parametreleri).

**Recovery key.** 32 random bytes plus a 2-byte checksum (`BLAKE2b-256("keykey/v1/recovery-checksum" || key)`, first 2 bytes), encoded as 55 characters of Crockford Base32. It is shown once and not stored. `KEK = HKDF-Expand(key, "keykey/v1/kek/recovery", 32)`. The checksum only catches typos before any crypto runs.

## Associated data

Every ciphertext is bound to its context through AEAD associated data. Fields are length-prefixed (4-byte big-endian length, then content) to avoid ambiguity; numbers are 8-byte big-endian and strings UTF-8.

## Vault header

The header is JSON, so no extra parser code is needed and reviewers can read it. Binary fields are padded Base64.

```json
{
  "version": 1,
  "vaultId": "<16 bytes>",
  "kdf": { "algorithm": "argon2id13", "opsLimit": 3, "memLimit": 67108864, "salt": "<16 bytes>" },
  "slots": {
    "password": { "nonce": "<24 bytes>", "cipherText": "<48 bytes>" },
    "recovery": { "nonce": "<24 bytes>", "cipherText": "<48 bytes>" }
  }
}
```

Each slot is `XChaCha20-Poly1305(KEK, random nonce, vault key, AD)`.

| Slot | AD fields |
|---|---|
| `password` | `keykey/v1/wrap`, `vaultId`, `password`, `argon2id13`, `opsLimit`, `memLimit`, `salt` |
| `recovery` | `keykey/v1/wrap`, `vaultId`, `recovery` |

Parsing is strict: an unknown version or algorithm, a missing or unknown field, a wrong length, or a parameter outside the floor and ceiling is rejected. Because the KDF parameters and salt are in the AD, changing them makes the password slot fail to open.

## Records

Only the record ID, type, timestamps and format version are stored in plaintext. Everything else is inside the ciphertext, including name, username and URLs.

```text
record = version (1 byte, 0x01) || nonce (24 bytes) || ciphertext and tag
```

- The plaintext is padded to 256-byte blocks (`sodium_pad`), so the length doesn't reveal the password length.
- `otp` records use the OTP key; all other types use the record key.
- Record types are `login`, `otp`, `settings` and, since 1.4.0, `card` and `note`. Each content is strict JSON with a version; unknown versions, missing or extra fields are rejected. A card stores the number as digits only (up to 19), expiry month and year, a security code (up to 4 digits) and a PIN (up to 12 digits); the brand is derived from the number, never stored. A note holds at most 64 KiB of text. Details: [Kart kaydının içeriği](guvenlik-tasarimi.md#kart-kaydının-içeriği), [Not kaydının içeriği](guvenlik-tasarimi.md#not-kaydının-içeriği).
- AD: `keykey/v1/record`, `vaultId`, record ID (16 bytes), type.

**Storage.** A single SQLite file in the app's private directory. The file as a whole isn't encrypted; protection comes from per-record encryption. `secure_delete` is on and `journal_mode` is `DELETE`. Android backup and device transfer are disabled. Details: [Depolama](guvenlik-tasarimi.md#depolama).

## Lock

- **Wrong-password delay.** After 3 failures the next attempt waits 5 s, then 15 s, 30 s, 1 min, 5 min, and from the 9th failure 15 min. The counter is written to disk before Argon2id starts and reset only on success, so killing the app mid-attempt doesn't save attempts. The vault is never wiped automatically. The counter is unencrypted and is only the app's own rule ([Known limitations](#known-limitations) item 6).
- **Auto-lock.** KeyKey locks as soon as it goes to the background, and after 5 minutes without a touch. One exception: while a document or photo picker that KeyKey itself opened is showing, locking waits at most 3 minutes.

## Fingerprint

Fingerprint unlock is optional, and its slot isn't part of the header or backups.

- The Keystore key `keykey_biometric_v1` is AES-256-GCM, requires user authentication on every use (`AUTH_BIOMETRIC_STRONG`, no time window, no device PIN), is invalidated when a new fingerprint is enrolled, and is created in StrongBox when available.
- Wrap: `AES-256-GCM(Keystore key, iv, vault key, AD)`, where AD = `keykey/v1/wrap`, `vaultId`, `biometric`.
- Unlocking goes through `BiometricPrompt` with a `CryptoObject`, so a successful match is required to use the key, not just a yes/no callback.
- Known gap: when unlocking, the raw vault key crosses the Dart/Kotlin bridge, and the copies on both sides can't be zeroed.

Details: [Biyometri](guvenlik-tasarimi.md#biyometri).

## Backups

A backup is a single `.keykey` file. It has no separate password: it opens with the master password or the recovery key that were valid when it was taken.

```text
file  = magic "KEYKEYBK" || version 0x01 || header length (4 bytes BE) || vault header
        || secretstream header (24 bytes) || chunk || chunk || ...
chunk = length (4 bytes BE) || encrypted chunk
```

- Backup key: `HKDF-Expand(vault key, "keykey/v1/backup", 32)`.
- Encryption: `crypto_secretstream_xchacha20poly1305`, with chunks of at most 64 KiB and the last one tagged `FINAL`. Truncated files, trailing data and reordered chunks are rejected. Every chunk's AD contains `keykey/v1/backup` and the file bytes up to the end of the header.
- Inside are the records exactly as stored, still encrypted with the record and OTP keys, so a backup has two layers. Record count and types are hidden by the outer layer.
- Restore checks the structure, decrypts and validates every record before writing anything, and writes in one SQLite transaction.
- Limits: 64 MiB per file and 100 000 records. The file size is computed before encryption and an oversized backup is not written.
- Payload version 2 (1.4.0) adds `card` and `note`. A backup without cards or notes is still written as version 1, so older apps can open it; 1.3.0 and earlier reject a version 2 backup as damaged. Newer file or payload versions are reported as "update the app".

Details: [Yedekleme](guvenlik-tasarimi.md#yedekleme).

## Sync

Sync (1.8.0) is off by default. The user enters a WebDAV folder (Nextcloud, ownCloud or another server), a username and an app password. Design: [senkron.md](senkron.md) (Turkish).

- **Files.** Each phone writes one file, `keykey-sync-<6 hex>.keykey`, in the backup format above (payload version 4 with a `sync` object holding the device ID, model, deletion records and the password/recovery slot times). The settings record and the app password are never in it. The server sees names, sizes and times, not content.
- **Client.** HTTPS with system CAs only (plain `http` only on loopback); no user info, query or fragment in the address; redirects are not followed; no cookies; HTTP Basic on every request; 10 s connect and 60 s request timeouts; 1 MiB listing and 64 MiB file limits. Writes go to a `.part` file, are read back and compared byte by byte, then moved into place. Error messages carry neither the path nor the credentials.
- **App password** is stored only inside the vault, in the encrypted settings record; it is part of the (encrypted) backups.
- **Merge** is per record: every remote record is decrypted with the open vault's key and validated, and one bad record makes the whole file ignored. The newest `updatedAt` wins; a deletion record wins when it is at least as new. A file with any time more than 24 hours in the future is ignored. A losing login password is kept in the winner's password history. Password and recovery slots merge separately by their own change times.
- **Other vaults.** If the folder holds another vault's file, sync is not turned on and stops. The phone can join that vault only with that vault's master password or recovery key; its records are re-encrypted and merged in one transaction, and its old master password and recovery key stop working.
- **Restore while sync is on** never deletes anything through sync: merged and replaced records are stamped with the current time so they win over older deletions elsewhere.

Details: [Senkron](guvenlik-tasarimi.md#senkron).

## Autofill

- **Apps.** A login is bound to a package name and the SHA-256 digest of the app's signing certificate, checked with `PackageManager.hasSigningCertificate`. The package name alone is never trusted.
- **Websites.** `webDomain` is used only if the request comes from a trusted browser: one whose package name and release signing digest are on an embedded list taken from Google's Credential Manager privileged-apps list. Domains are reduced to the registrable domain with an embedded Public Suffix List, including its private section. IDNs are compared as punycode, and IP addresses only match exactly.
- **WebViews (AutoSpill).** A `webDomain` from a non-browser app isn't used for matching, because the host app can read what gets filled.
- **Suspicious cases ask for confirmation**: no match, a WebView, plain `http`, or a matching package name with a different signature (shown as "this app may be fake"). With a signature mismatch KeyKey never offers to bind the app.
- The autofill screen has its own lock and the same window protections.
- **Cards (1.5.0).** Payment forms get a separate "Fill card with KeyKey" suggestion. A card isn't bound to any site or app, so it is always picked from the list after unlocking, and the list title names the target. The card PIN is never filled, nothing is copied to the clipboard, and plain `http` pages ask for confirmation. Card security-code fields are no longer mistaken for passwords, so KeyKey doesn't offer to save them.

Details: [Otomatik doldurma](guvenlik-tasarimi.md#otomatik-doldurma), [Kart doldurma](guvenlik-tasarimi.md#kart-doldurma).

## Other protections

- **Screen.** `FLAG_SECURE` everywhere and no recents screenshot. Other apps' overlays are hidden (`setHideOverlayWindows`, Android 12+), and obscured touches are dropped on Android 11. Windows are marked `accessibilityDataSensitive` on Android 14+. [Arayüz koruması](guvenlik-tasarimi.md#arayüz-koruması).
- **Clipboard.** Copies are marked sensitive (Android 13+) and cleared after 30 seconds, by a timer or an alarm. The clipboard is cleared only if it still holds KeyKey's value, compared by SHA-256. [Pano](guvenlik-tasarimi.md#pano).
- **Optional extra check for 2FA codes.** Codes are shown only after a fingerprint or master password check. That check really unwraps the vault key, and it counts towards the wrong-password delay.
- **Imports.** Imports from Google Authenticator, Aegis, 2FAS, Bitwarden, Chrome, Firefox and KeePassXC treat files as untrusted: size and KDF limits apply, and the parsers are fuzzed with randomly corrupted input. scrypt and PBKDF2 are our own Dart code, used only to open other apps' exports and verified against RFC vectors.
- **Breach check.** Starts only when the user taps **Check online**; nothing is sent when the report or the vault opens. Prefixes are shuffled, at most 4 requests run at once, responses are padded (`Add-Padding`), the client sends `User-Agent: KeyKey` and no cookies, and responses over 1 MiB are refused. Every response line must match `^[0-9A-F]{35}:[0-9]+$`; one bad line fails the whole check and no partial result is shown. The result is kept in memory only and is dropped when the screen closes or the vault locks. Finding: Flutter 3.47 does not apply Android's cleartext policy to Dart's `HttpClient`, so the client enforces HTTPS itself; the manifest still sets `usesCleartextTraffic="false"` and a network security config for platform code. [Sızıntı kontrolü](guvenlik-tasarimi.md#sızıntı-kontrolü).
- **Logging.** The app writes nothing to logcat. A scan of the whole device log during all tests found none of the test secrets, with one exception outside KeyKey: on Android 11, after a card number was copied, Gboard passed the clipboard text to the system text classifier, which wrote the number into an exception message (`NumberFormatException`). Android 13+ (sensitive clipboard flag) showed nothing. Logcat is readable only by the system and over adb. [Kayıtlar](guvenlik-denetimi.md#kayıtlar-logcat).

## Known limitations

These are accepted risks, numbered as in the [Turkish list](guvenlik-tasarimi.md#bilinen-sınırlar).

1. **Rollback isn't detected.** Someone who can write to the disk can replace a record, or the whole vault, with an older copy that is still valid.
2. **Record deletion isn't detected.** This only loses data; it doesn't reveal any.
3. **Metadata leaks.** Record count, types, timestamps and the number of 256-byte padding blocks are visible in the database (not in backups). This includes how many cards and notes there are, and roughly how long a long note is.
4. **Password strength matters.** Argon2id slows guessing down but can't fix a weak password; backups have the same limit.
5. **The wrapped key doesn't rotate.** After a password change, someone holding the old password and an old header can still reach the vault key, and old backups still open with the old password.
6. **The wrong-password delay is only the app's rule.** It doesn't limit guessing against a copied file.
7. **Strings stay in memory after lock.** The typed master password and values shown on screen can stay in Dart heap strings after locking; the audit still found them 2.5 minutes later. Keys, the recovery key and 2FA secrets were not found. Reading this memory requires root or code execution in the process.
8. **The fill notification is outside the secure window.** After a fill, a notification with the entry's name appears outside KeyKey's `FLAG_SECURE` window, so screen recording and accessibility services can see it. Usernames and passwords are not in it.
9. **The breach check trusts the service and leaves a trace.** Have I Been Pwned (and Cloudflare) see the IP address, the prefixes and the time. The set of prefixes from one IP can act as a fingerprint of a vault; it does not reveal a password on its own. A random password's 5-character prefix gives away 20 bits and leaves 140; a weak password's prefix narrows a dictionary search (weak passwords are already flagged in the report). "Not seen in breaches" does not mean "safe".
10. **Sync trusts the clocks.** "Newest wins" uses each phone's clock; more than 24 hours ahead is refused, but a smaller skew can pick the wrong version. If the same record changes on two phones between syncs, the older change is lost (only a password is kept in the history).
11. **Deletion records are unencrypted and spread.** Their count and times are visible in the database. Someone who can write to the database can affect a record on every phone through sync with a deletion or version up to 24 hours in the future; before sync it affected only that phone.
12. **The server can delay.** By withholding, deleting or rolling back a phone's file the server can delay changes; an old file can't undo newer changes because merging only applies what is newer.
13. **A password change is not a revocation.** An unused phone's sync file and the server's file history open with the old password, and the unchanged vault key also opens later files. A lost phone is stopped by revoking its app password on the server.

Also: Android 11-13 offer no way to hide the app from accessibility services, and a malicious keyboard sees everything that is typed.

## Self-audit

The project audited itself against OWASP MASVS v2 with release builds ([summary table](guvenlik-denetimi.md#özet)). It is not an independent audit.

- **Checks that pass:**
  - storage scan on a rooted emulator;
  - no secrets in logcat;
  - exported components protected;
  - no WebView;
  - network code confined to one file and checked by a test (since 1.6.0 the app has the `INTERNET` permission for the breach check);
  - dependency scan with OSV.
- **Fixed during the audit:** Flutter's deep linking was enabled by default, so any app could open KeyKey on a chosen screen while the vault was unlocked. It is now disabled, and CI checks that it stays disabled.
- **Out of scope on purpose:** anti-tampering, root detection and obfuscation. The project is open source, and its security rests on cryptography rather than on hiding code.
- **Tested on a real device:** a Samsung Galaxy S20 FE (Android 13). The fingerprint key is in StrongBox, and enrolling a new fingerprint invalidates it.

## Release signing

Releases are built and signed by a GitHub Actions workflow when a `v*` tag is pushed; the signing key lives only in a GitHub environment that accepts `v*` tags and needs the maintainer's approval for each run. Two CI builds of the same commit produce byte-identical APKs. Signing certificate SHA-256:

```
66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0
```

The key (RSA 4096) was generated on the maintainer's machine; encrypted backups are kept offline and off-site. Details: [Yayın](yayin.md).

## Reporting a vulnerability

Please don't open a public issue. Use GitHub's [private security advisory form](https://github.com/aaudraa/KeyKey/security/advisories/new); see [`SECURITY.md`](../../.github/SECURITY.md). Design criticism that isn't a vulnerability is welcome as a regular issue, in English or Turkish.
