# SQLite

KeyKey'in veritabanı motoru. `sqlite3` paketinin derleme kancası bu dosyayı paketin varsayılan derleme seçenekleriyle derler (`pubspec.yaml`, `hooks: user_defines: sqlite3`). Hazır kütüphane indirilmez.

| | |
|---|---|
| Sürüm | 3.54.1 |
| Kaynak | https://sqlite.org/2026/sqlite-amalgamation-3540100.zip |
| Arşivin SHA3-256 özeti (sqlite.org'un yayımladığı) | `92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30` |
| `sqlite3.c` SHA-256 | `0c657666d819f261cc4007526ad57e1669de9949df7a8ea847aa284a2bf0ee52` |
| Lisans | Kamu malı (https://sqlite.org/copyright.html) |

Arşivden yalnızca `sqlite3.c` alındı, değiştirilmedi. Güncellemek ve doğrulamak için: `bash resources/scripts/sqlite-guncelle.sh <sürüm>`.
