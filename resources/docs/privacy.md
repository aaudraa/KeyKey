# Privacy policy

**Applies to:** KeyKey 1.0 and later · **Last updated:** 2026-11-09 · Türkçe: [gizlilik.md](gizlilik.md)

KeyKey collects no data and sends nothing anywhere. The app has no internet permission, so it could not send data off the device even if it tried. Anyone can verify this from the installed app's permissions or from the source code.

## What is not collected

- No account, registration or identity. You do not sign up to use KeyKey.
- No analytics, usage statistics, advertising ID or ads.
- No crash reporting. If you want to report a bug, you open a GitHub issue and decide what to share.
- No third-party tracking libraries.

## What stays on your device

- Your passwords, 2FA accounts, notes and settings live only on your device, in a database encrypted with a key derived from your master password. Encryption details are in the [security summary](security-summary.md).
- Android cloud backup is disabled; the vault is not backed up to your Google account.
- Uninstalling the app deletes all of its data. Without a backup it cannot be recovered.

## Permissions

| Permission | Why |
|---|---|
| Camera | Requested only while scanning a 2FA QR code. Images are not stored and never leave the device. |
| Biometrics (fingerprint) | To unlock the vault with a fingerprint. The fingerprint itself never reaches KeyKey; Android only reports "verified". |
| Hide overlay windows | So other apps cannot draw over KeyKey and trick your taps while it is on screen. |

KeyKey does not request internet, location, contacts, storage or "see all apps" (`QUERY_ALL_PACKAGES`) permissions.

## Autofill

If you select KeyKey as your autofill service, Android gives KeyKey the structure of a login form when you tap it (field types, the app's package name, the site's domain in a browser). KeyKey uses this only to suggest the right entry and does not store it. If you accept a save prompt, only the username and password you confirm are added to the vault. To link entries to apps, KeyKey can see the list of apps that have a launcher icon.

## Clipboard

Copied passwords and 2FA codes are marked as sensitive on the clipboard (Android 13 and later, hidden from keyboard previews) and cleared after 30 seconds.

## Files

Backup, export and import files are written to or read from only the location you pick in Android's file picker. If you pick a location such as Drive, Android itself moves the file there; KeyKey does not go online. Plain-text export asks for confirmation twice and states clearly that the file is unencrypted.

## Changes

If this policy changes, the new version is published in this file and in the [changelog](../CHANGELOG.md). Adding a feature that needs the internet (sync, for example) would be a separate decision and would be stated plainly here.

## Contact

For questions, open an issue on GitHub: https://github.com/aaudraa/KeyKey/issues. To report a security vulnerability, see the [security policy](../../.github/SECURITY.md).
