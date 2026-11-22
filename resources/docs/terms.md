# Terms of use

**Version:** 4 · **Date:** 2026-11-22 · Türkçe: [kosullar.md](kosullar.md)

KeyKey shows these terms once before a vault is created or opened; you cannot continue without ticking "I have read and understood this, and I accept it." They can be read again under Settings → About → **Terms of use**. This file matches the text in the app; if the terms change, the version number goes up and the app asks once more. Data details are in the [privacy policy](privacy.md); the full license is in [LICENSE](../../LICENSE).

Please read this before you start using KeyKey. We kept it short; every point describes how KeyKey actually works.

## Your data is in your hands

Your passwords, 2FA accounts, cards and notes are kept in the vault on this phone. A backup or export file is only created when you ask for it, and saved where you choose. KeyKey has no account and no server, shows no ads and collects no usage data. It goes online only for features you turn on yourself: the breach check in the password report (your passwords themselves are never sent), sync if you turn it on, and, if you turn it on, verifying an app's website during autofill (nothing from your vault is sent to the site). When you open a link, the page opens in your browser. The developers cannot see, collect or store your data.

## How the vault is protected

The vault is protected by a key derived from your master password with Argon2id; entries are encrypted with XChaCha20-Poly1305. Your master password is never stored. If you turn on fingerprint unlock, the vault key is protected by a key kept in the phone's secure hardware (Android Keystore).

## Only you hold the master password and recovery key

Only you know your master password and recovery key. If you lose both, your vault cannot be opened; no one, including the developers, can recover your data. Don't share either of them: KeyKey will never ask for your master password by email or message.

## Backups are up to you

If the phone is lost or broken, or KeyKey is uninstalled, the vault is gone too. Taking regular encrypted backups and keeping them somewhere safe is your responsibility. An unencrypted export file is not protected; delete it when you are done.

## If you turn on sync

If you turn on sync, an encrypted copy of your vault is written to the WebDAV server you choose and synced with your phones that use the same folder. The copy is encrypted with your master password; the server cannot read it. KeyKey and its developers have no access to that server. Keeping the server secure and storing the app password are up to you or the server provider. Sync is not a backup: a record deleted on one phone is deleted on the other phones too, so keep taking backups.

## Your phone's security

No app can protect your data on a compromised phone. Keep your phone updated and use a screen lock; don't use KeyKey on a rooted phone or alongside apps you don't trust. A copied password is cleared from the clipboard after 30 seconds; until then, apps that can access the clipboard may read it, and some keyboards' clipboard history may keep it longer.

## Open source, not independently audited

KeyKey is free and open source (GPL-3.0); anyone can review its code. Most of the code was written with an AI assistant. KeyKey has not yet had an independent security audit.

## No warranty

KeyKey is provided as is, without any warranty. To the extent permitted by applicable law, the developers are not liable for data loss, for your data falling into others' hands, or for any damage arising from using KeyKey. See sections 15 and 16 of the GPL-3.0 license (Settings → About → Licenses).
