# Privacy policy

**Applies to:** KeyKey 1.0 and later · **Last updated:** 2026-11-20 · Türkçe: [gizlilik.md](gizlilik.md)

KeyKey collects no data. There is no account and KeyKey has no server; your vault stays on this phone, encrypted. Since 1.6.0 KeyKey has the internet permission, and it goes online only for features you turn on yourself: the [breach check](#breach-check) in the password report, [sync](#sync) if you turn it on, and, if you turn it on, [verifying an app's website](#verifying-an-apps-website) during autofill. Your passwords and your vault do not leave the device during the breach check or website verification; with sync, only a copy of your vault encrypted with your master password goes to the server you choose. All network code lives in three files, and a test on every build checks that there is no network code anywhere else; anyone can verify this from the source code.

## What is not collected

- No account, registration or identity. You do not sign up to use KeyKey.
- No analytics, usage statistics, advertising ID or ads.
- No crash reporting. If you want to report a bug, you open a GitHub issue and decide what to share.
- No third-party tracking libraries.

## What stays on your device

- Your passwords, cards, secure notes, 2FA accounts and settings live only on your device, in a database encrypted with a key derived from your master password. Encryption details are in the [security summary](security-summary.md).
- Android cloud backup is disabled; the vault is not backed up to your Google account.
- If you turn on sync, the folder address, username and app password are stored encrypted inside the vault, in the settings record. They are also part of the vault's backup (the backup is encrypted).
- There are two exceptions, each a small, separate, unencrypted file in the app's own folder that holds nothing else:
  - Your theme choice (system, light or dark), so the lock screen can open in your chosen theme.
  - That you accepted the [terms of use](terms.md): only the version number of the accepted terms. The terms are shown before the vault is opened, so this can't be kept inside the vault.
- Uninstalling the app deletes all of its data. Without a backup it cannot be recovered.

## Permissions

| Permission | Why |
|---|---|
| Camera | Requested only while scanning a 2FA QR code. Images are not stored and never leave the device. |
| Biometrics (fingerprint) | To unlock the vault with a fingerprint. The fingerprint itself never reaches KeyKey; Android only reports "verified". |
| Hide overlay windows | So other apps cannot draw over KeyKey and trick your taps while it is on screen. |
| Internet | For the breach check in the password report, when you tap it; if you turn it on, for sync, only with the server you entered; if you turn it on, to verify an app's website during autofill. What is sent is below: [breach check](#breach-check), [sync](#sync), [website verification](#verifying-an-apps-website). |

KeyKey does not request location, contacts, storage or "see all apps" (`QUERY_ALL_PACKAGES`) permissions.

## Autofill

If you select KeyKey as your autofill service, Android gives KeyKey the structure of a login form when you tap it (field types, the app's package name, the site's domain in a browser). KeyKey uses this only to suggest the right entry and does not store it. If you accept a save prompt, only the username and password you confirm are added to the vault. To link entries to apps, KeyKey can see the list of apps that have a launcher icon.

When you fill in an app, KeyKey also reads the websites Android has verified for that app (Android 12 and later). This stays on the phone; nothing goes online.

## Clipboard

Copied passwords, card details, notes and 2FA codes are marked as sensitive on the clipboard (Android 13 and later, hidden from keyboard previews) and cleared after 30 seconds.

## Breach check

If you tap **Check online** in the password report, KeyKey asks [Have I Been Pwned](https://haveibeenpwned.com/Passwords)'s Pwned Passwords service whether your passwords have appeared in known data breaches. Nothing is sent until you tap; there is no automatic or background check.

- **What is sent:** only the first 5 characters of each password's SHA-1 hash (for example `5BAA6`). The password itself, the rest of the hash, the entry name, username and website are not sent. The comparison happens on the phone (k-anonymity).
- **Where it goes:** `api.pwnedpasswords.com` (Have I Been Pwned; the service runs behind Cloudflare), over HTTPS only.
- **What the other side sees:** your IP address, the prefixes asked for, and the time. Apart from `User-Agent: KeyKey` the request carries no identifier, cookie or account. The set of prefixes from one IP address could act as a fingerprint of a vault; on its own it does not reveal a password.
- **What is kept:** nothing. The result stays in memory only and is gone when you leave the screen or the vault locks.

The data belongs to Have I Been Pwned and is used under CC BY 4.0.

## Sync

If you turn on Settings → **Sync**, KeyKey writes an encrypted copy of your vault to the WebDAV folder you entered (Nextcloud, ownCloud or another WebDAV server) and reads the files of your phones that use the same folder. Nothing is sent while sync is off.

- **What is sent:** A copy of your vault, encrypted with your master password in the same format as a backup: records, the IDs and times of deleted records, and the phone's model (for example SM-G780G). The file name holds this installation's random 6-character ID (`keykey-sync-a1b2c3.keykey`). The username and app password are sent inside HTTPS with every request to sign in to the server; they are not written to the file.
- **Who receives it:** Only the server you entered, only over HTTPS (redirects are not followed). KeyKey and its developers have no server; the developers have no access to the files.
- **What the other side sees:** Your IP address and the file names, sizes and modification times. It cannot read or change the content without your master password; it can try to guess your master password offline, so a strong master password matters.
- **What is stored:** One file per phone on the server. When you turn sync off you can delete this phone's file as well; the server's file history and trash are out of KeyKey's reach.

## Verifying an app's website

If you turn on Settings → Autofill → **Verify the app's website online** (off by default) and nothing matches in an app, KeyKey reads the `assetlinks.json` file of the site the app claims as its own. If the file approves the app, the login matches and the app is linked to it; that login is not checked online again. Details in the [design document](uygulama-site-eslestirme.md) (Turkish).

- **What is sent:** Only a request for a fixed address: `https://<site>/.well-known/assetlinks.json`. Nothing from your vault, no entry name, username or password.
- **Where it goes:** Only to a site that the app claims as its own and that you have a login for, only over HTTPS (redirects are not followed). At most 4 sites per fill.
- **What the other side sees:** Your IP address and the time; from this it can infer that you are about to fill in an app related to that site and that your vault has a login for it. The request carries no identifier, cookie or account other than `User-Agent: KeyKey`.
- **What is stored:** If approved, the app is linked to the login (inside the vault, encrypted). Otherwise nothing.

## Files

Backup, export and import files are written to or read from only the location you pick in Android's file picker. If you pick a location such as Drive, Android itself moves the file there; KeyKey never sends the file anywhere. Plain-text export asks for confirmation twice and states clearly that the file is unencrypted.

## Links

When you tap **Open website** on an entry, or a link under About in settings, KeyKey hands that one address to your browser and the browser loads the page. Nothing else is passed along; your browser loads the page, not KeyKey.

## Changes

If this policy changes, the new version is published in this file and in the [changelog](../CHANGELOG.md). Any new feature that goes online will be stated plainly here, and the terms of use will be asked again.

## Contact

For questions, open an issue on GitHub: https://github.com/aaudraa/KeyKey/issues. To report a security vulnerability, see the [security policy](../../.github/SECURITY.md).
