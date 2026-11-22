# KeePass test dosyaları

KeePass içe aktarmanın (Faz 20, #177) testlerinde kullanılan `.kdbx` dosyaları ve anahtar dosyaları. Hepsi değiştirilmeden duruyor.

| Klasör | Kaynak | Lisans |
|---|---|---|
| `pykeepass/` | [libkeepass/pykeepass](https://github.com/libkeepass/pykeepass) `tests/`, commit `aec256659e7b2b497a37891476241b720f60c84e` | GPL-3.0 |
| `keepassxc/` | [keepassxreboot/keepassxc](https://github.com/keepassxreboot/keepassxc) `tests/data/`, commit `cd42236540c1cfca332c0f051d981acfdacf7b4e` | GPL-2.0 ya da GPL-3.0 |
| `keykey/` | `resources/scripts/kdbx-ornek.py` ile pykeepass 4.2.0'ın yazıcısıyla üretildi (2026-11-22) | KeyKey ile aynı |

İndirme: `https://raw.githubusercontent.com/<depo>/<commit>/<yol>`. Parolalar kaynak depoların kendi testlerinden (`pykeepass/tests/tests.py`, KeePassXC `tests/TestKdbx2.cpp`, `TestKdbx3.cpp`, `TestKdbx4.cpp`, `TestKeys.cpp`); her dosya 2026-11-22'de pykeepass 4.2.0 ile açılarak doğrulandı (KDBX 2 dosyalarını pykeepass açamıyor).

| Dosya | Parola | Anahtar dosyası | Sürüm | Şifre | KDF |
|---|---|---|---|---|---|
| `pykeepass/test3.kdbx` | `password` | `test3.key` | 3.1 | AES | AES-KDF |
| `pykeepass/test4.kdbx` | `password` | `test4.key` | 4.0 | ChaCha20 | Argon2d |
| `pykeepass/test4_aes.kdbx` | `password` | `test4.key` | 4.0 | AES | Argon2d |
| `pykeepass/test4_aeskdf.kdbx` | `password` | `test4.key` | 4.0 | AES | AES-KDF |
| `pykeepass/test4_chacha20.kdbx` | `password` | `test4.key` | 4.0 | ChaCha20 | Argon2d |
| `pykeepass/test4_twofish.kdbx` | `password` | `test4.key` | 4.0 | Twofish | Argon2d |
| `pykeepass/test4_hex.kdbx` | `password` | `test4_hex.key` | 4.0 | ChaCha20 | Argon2d |
| `pykeepass/test4_keyx.kdbx` | `password` | `test4_keyx.keyx` | 4.0 | ChaCha20 | Argon2d |
| `pykeepass/test4_aes_uncompressed.kdbx` | `password` | — | 4.0 | AES | Argon2d |
| `pykeepass/test4_chacha20_uncompressed.kdbx` | `password` | — | 4.0 | ChaCha20 | Argon2d |
| `pykeepass/test4_twofish_uncompressed.kdbx` | `password` | — | 4.0 | Twofish | Argon2d |
| `pykeepass/test4_argon2id.kdbx` | `password` | — | 4.0 | AES | Argon2id |
| `pykeepass/test4_blankpass.kdbx` | boş | `test4.key` | 4.0 | AES | Argon2d |
| `keepassxc/Format200.kdbx` | `a` | — | 2.0 | AES | AES-KDF |
| `keepassxc/Format300.kdbx` | `a` | — | 3.0 | AES | AES-KDF |
| `keepassxc/Format400.kdbx` | `t` | — | 4.0 | ChaCha20 | Argon2d |
| `keepassxc/NonAscii.kdbx` | `Δöض` | — | 3.1 | AES | AES-KDF |
| `keepassxc/Compressed.kdbx` | boş | — | 3.1 | AES | AES-KDF |
| `keepassxc/ProtectedStrings.kdbx` | `masterpw` | — | 3.1 | AES | AES-KDF |
| `keepassxc/NewDatabase.kdbx` | `a` | — | 3.1 | AES | AES-KDF |
| `keepassxc/RecycleBinWithData.kdbx` | `123` | — | 3.1 | AES | AES-KDF |
| `keepassxc/BrokenHeaderHash.kdbx` | boş | — | 3.1 | AES | AES-KDF; `Meta/HeaderHash` bilerek yanlış |
| `keepassxc/FileKeyBinary.kdbx` | yok | `FileKeyBinary.key` (32 bayt) | 2.4 | AES | AES-KDF |
| `keepassxc/FileKeyHex.kdbx` | yok | `FileKeyHex.key` (64 onaltılık) | 2.4 | AES | AES-KDF |
| `keepassxc/FileKeyHashed.kdbx` | yok | `FileKeyHashed.key` (SHA-256) | 2.4 | AES | AES-KDF |
| `keepassxc/FileKeyXml.kdbx` | yok | `FileKeyXml.key` (XML 1.0) | 2.4 | AES | AES-KDF |
| `keepassxc/FileKeyXmlV2.kdbx` | yok | `FileKeyXmlV2.keyx` (XML 2.0) | 3.1 | AES | AES-KDF |
| `keepassxc/FileKeyXmlV2HashFail.kdbx` | yok | `FileKeyXmlV2HashFail.keyx` (özeti bilerek yanlış) | 3.1 | AES | AES-KDF |
| `keykey/keykey_ornek.kdbx` | `keykey` | — | 4.0 | AES | Argon2d |

`NonAscii.kdbx.key` KeePassXC'in deposundaki adıyla duruyor ama anahtar dosyası değil; testlerde kullanılmıyor.

pykeepass'ın hesapladığı dönüştürülmüş anahtarlar (anahtar türetmenin bilinen sonucu):

| Dosya | Dönüştürülmüş anahtar |
|---|---|
| `keepassxc/NewDatabase.kdbx` | `babcefd380208fa1e4d39b5e085047a9ad808bf27dc6c10c63ccf88f811b7581` |
| `keepassxc/RecycleBinWithData.kdbx` | `108beef7db5c8c48772e319ff848416715b5b4596922bfe4e36d0034915f3b89` |
| `pykeepass/test4.kdbx` | `06e36d85bdb14fb2c7471e4fe2e9791cd82994c77bf101d25486ebbc104e675b` |

## SHA-256

```
681e9117b297ee7be9d569f066b07f2a361d1bf0aae49074033022425f267a00 keepassxc/BrokenHeaderHash.kdbx
392b089bf3f17f7e507dc2d97584493f1b709f6989b37c2b964bfc8b21e994b8 keepassxc/Compressed.kdbx
03ed0c43fc4604f45d43c8bc09e7b4c1390c31f53324eee92095dbeff862470c keepassxc/FileKeyBinary.kdbx
fe9f5fd9d5f6d37eecd342e21dcd7bf12fbe489018905d06e2085666069b867d keepassxc/FileKeyBinary.key
ee5d4ef89730977cee7df48e935d974e67000d05b661a0dbc08acaf64bbe95f1 keepassxc/FileKeyHashed.kdbx
a86c55910c7e33606dfe88eb3da46b80b73287c63544ea82eb40dadf80fe8df4 keepassxc/FileKeyHashed.key
5fc88af6beae92251a6ec4112e64d0d60c2c18d464215cd9b221e9af960d1cf6 keepassxc/FileKeyHex.kdbx
c98cddef3c306daaae8b528048b73d2a1959d3755c4b316f3d8eaf6822230e6f keepassxc/FileKeyHex.key
ab833b97f60fd93d64caf8e62709a2a4838b1694ee66e59315c19c25d2ecfb4a keepassxc/FileKeyXml.kdbx
3d3a74ac85d477b5f75c91b320162b35e7294facda5559bf7f86cb4e83b4e26f keepassxc/FileKeyXml.key
100d37b42d3327db4b01f757a91a205dc3a72f2b6766a9403200c5485138eaef keepassxc/FileKeyXmlV2.kdbx
f44cf0cac25c3f3b116fb57dc05db77479b18ff56aecf1b91766e951cea1ee4c keepassxc/FileKeyXmlV2.keyx
6afb37868222b71f5e8e8b260e9bcf22cec6cc01542c3ef853d3b7a56f778d39 keepassxc/FileKeyXmlV2HashFail.kdbx
bca06e3f58d576dc9929c5d1153af0bb415bdbc12a0c19f70c41941178f14cd8 keepassxc/FileKeyXmlV2HashFail.keyx
2677d1a4bfa1b7fe8935d9a1a4a2e087c9f0b1e1d7bca65ab24fde0ea6f29cf9 keepassxc/Format200.kdbx
ba2e4b5372b34e9856a51edc97481e03380ce64b9338c081b3ea43dd309ae506 keepassxc/Format300.kdbx
4f23b3f5f6c71209e135dab92d0f06034315d3f70e3e2ef3ec3a77ff37b49435 keepassxc/Format400.kdbx
5fdee9fff96df5ce58c331a56f4b253ad32e864dba1a86b98df14659283daa29 keepassxc/NewDatabase.kdbx
e8a69ba7e0cbd86a98b9a9d8fb6df8deecb052a4a3da842b200776434cb760e4 keepassxc/NonAscii.kdbx
dba9a6c73f326d14341cf78887b1600ffa9e155335c2144c8399a2d6462e25ca keepassxc/NonAscii.kdbx.key
15efb80917ffff30173e75d5bb53c270a10076b26a90f4a80d2071b71f318d8c keepassxc/ProtectedStrings.kdbx
8cba4f2fa04a12550cd0c0fae72701c6281bb7cc76db2ca4502bb180a5b4d4c8 keepassxc/RecycleBinWithData.kdbx
bdb5c8fc55515de8293bd992fab467874dba164c3c16d8036a32ee78d1101cd4 keykey/keykey_ornek.kdbx
5f6fb723d94d597b1e1c27acbe1572c0a0e4607f16748afddff40ef2598b9d7f pykeepass/test3.kdbx
b37d0a7a11eca613e161b29ba6f280af2506040d256e338b9c33c89f142c29ae pykeepass/test3.key
b0f96854452ffdf73c448378f91ae136156e95e64c122152621f9dbdeaf4a9a4 pykeepass/test4.kdbx
c0832b7d8785b059e1dc6de4a2e8b1ff10cdeb2ae35647b79922109aa0540297 pykeepass/test4.key
68f1a0472526b22fba0e6b4d1c64ab5858f59647321307bcd2b015a51a174823 pykeepass/test4_aes.kdbx
400f6b3af6c8573832cef95823b4fcf44986e6e2565fd835eda3f1defa513663 pykeepass/test4_aes_uncompressed.kdbx
cfe32681d5ff6f74f601d29ad22b41c9bc310eb8470bc650f83431f2bcd98ebd pykeepass/test4_aeskdf.kdbx
c087fd7660ddf95b4ec9355fe767c98145841abecb4f638631225225342697c9 pykeepass/test4_argon2id.kdbx
9d339a8433e6684a2227ca621ff849b0e84c74b44c8e843d13ba5217b34c9125 pykeepass/test4_blankpass.kdbx
e5994bae6f948cba6b38cf8af15c5154d985184e768e58d0b58fb327ee10db34 pykeepass/test4_chacha20.kdbx
d34d104856648491f0fbbf8d627673f2de0a0ac96d0000e93858794960ce80a5 pykeepass/test4_chacha20_uncompressed.kdbx
3cb8994e84f43186bf98cae404061846259a6406d8971a3ec74b9a93c1909898 pykeepass/test4_hex.kdbx
0b7f44b7e52fa47c779d80d51089eef1bbc3ad80cae12ecea1ab7ca9c05fc91a pykeepass/test4_hex.key
a0b04bd46fd48b963e4c394ac47de48daa34a1c71f115ba1f56e1c8ca6e774fc pykeepass/test4_keyx.kdbx
ebe8014428f8f141607295f41e3ee779e9722a0fc3f3195a8e395197285195f5 pykeepass/test4_keyx.keyx
02fe89e821bcc110ba9a3a0f942d472a277afc6ff65d961541ee4b7662113bb7 pykeepass/test4_twofish.kdbx
edba88821a4bbd5ad9864064e659bf678a742a581dded26a8b40597a3549b0f8 pykeepass/test4_twofish_uncompressed.kdbx
```
