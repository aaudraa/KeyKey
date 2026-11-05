# Sözcük listelerinin kaynakları

Bu klasördeki dosyalar uygulamaya veri olarak girer, kod değildir. İndirildikleri gibi duruyor; yalnızca satır sonları Unix biçimine çevrildi.

| Dosya | Kaynak | Lisans | SHA-256 |
|---|---|---|---|
| `eff_large_wordlist.txt` | [EFF büyük zar sözcük listesi](https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt), [açıklaması](https://www.eff.org/dice) | CC BY 3.0, © Electronic Frontier Foundation | `addd35536511597a02fa0a9ff1e5284677b8883b83e986e43f15a3db996b903e` |
| `common_passwords_10k.txt` | [SecLists, 10k-most-common](https://github.com/danielmiessler/SecLists/blob/master/Passwords/Common-Credentials/10k-most-common.txt) | MIT, © 2018 Daniel Miessler | `68782d6a4a19a4768d5f15dd66bd534e7a33055cc755411e33f16d18c50fdcce` |

2026-11-05 tarihinde indirildi. EFF listesinde 7776 farklı sözcük var, her satır `zar kodu<TAB>sözcük` biçiminde. Yaygın parola listesinde 10.000 farklı satır var.

Uygulama açılırken ikisinin de biçimi denetlenir. EFF listesinin lisansı, atıf istediği için uygulamanın lisanslar sayfasında da gösterilir.
