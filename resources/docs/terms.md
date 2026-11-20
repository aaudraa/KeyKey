# Terms of use

**Version:** 2 · **Date:** 2026-11-20 · Türkçe: [kosullar.md](kosullar.md)

KeyKey shows these terms once before a vault is created or opened; you cannot continue without ticking "I have read and understood this, and I accept it." They can be read again under Settings → About → **Terms of use**. This file matches the text in the app; if the terms change, the version number goes up and the app asks once more. Data details are in the [privacy policy](privacy.md); the full license is in [LICENSE](../../LICENSE).

Please read this before you start using KeyKey. We kept it short; every point describes how KeyKey actually works.

## Your data stays on this phone

Your passwords, 2FA accounts and notes are kept in the vault on this phone. A backup or export file is only created when you ask for it, and saved where you choose. KeyKey has no account and no server, shows no ads and collects no usage data. It goes online only for checks you start yourself; today the only one is the breach check in the password report, and your passwords themselves are never sent. When you open a link, the page opens in your browser. The developers cannot see, collect or store your data.

## How the vault is protected

The vault is protected by a key derived from your master password with Argon2id; entries are encrypted with XChaCha20-Poly1305. Your master password is never stored. If you turn on fingerprint unlock, the vault key is protected by a key kept in the phone's secure hardware (Android Keystore).

## Only you hold the master password and recovery key

Only you know your master password and recovery key. If you lose both, your vault cannot be opened; no one, including the developers, can recover your data. Don't share either of them: KeyKey will never ask for your master password by email or message.

## Backups are up to you

If the phone is lost or broken, or KeyKey is uninstalled, the vault is gone too. Taking regular encrypted backups and keeping them somewhere safe is your responsibility. An unencrypted export file is not protected; delete it when you are done.

## Your phone's security

No app can protect your data on a compromised phone. Keep your phone updated and use a screen lock; don't use KeyKey on a rooted phone or alongside apps you don't trust. A copied password is cleared from the clipboard after 30 seconds; until then, apps that can access the clipboard may read it, and some keyboards' clipboard history may keep it longer.

## Open source, not independently audited

KeyKey is free and open source (GPL-3.0); anyone can review its code. Most of the code was written with an AI assistant. KeyKey has not yet had an independent security audit.

## No warranty

KeyKey is provided as is, without any warranty. To the extent permitted by applicable law, the developers are not liable for data loss, for your data falling into others' hands, or for any damage arising from using KeyKey. See sections 15 and 16 of the GPL-3.0 license (Settings → About → Licenses).
