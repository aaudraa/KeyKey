"""KeePass cihaz testinin gömülü örneklerini üretir.

Cihazda çalışan testler bilgisayardaki dosyaları okuyamadığı için
test/fixtures/import/kdbx altındaki dosyalar Base64 olarak
integration_test/kdbx_fixtures.dart'a yazılır. Beklenen dönüştürülmüş
anahtarlar pykeepass 4.2.0 ile hesaplanır: KeyKey'in iki uygulamasından
(telefondaki ve testteki) bağımsız üçüncü bir uygulama. KDBX 2 dosyalarını
pykeepass açamadığı için onların anahtarı yazılmaz.

Kullanım: python resources/scripts/kdbx-cihaz-ornekleri.py
"""

import base64
import pathlib
import re

from pykeepass import PyKeePass

ROOT = pathlib.Path("test/fixtures/import/kdbx")
OUT = pathlib.Path("integration_test/kdbx_fixtures.dart")

# test/support/kdbx_fixtures.dart'taki kdbxFixtureKeys tablosu okunur; tek kaynak.
table = pathlib.Path("test/support/kdbx_fixtures.dart").read_text(encoding="utf-8")
entries = re.findall(
    r"'([\w/.]+\.kdbx)': \(\s*password: (null|'[^']*'),\s*keyFile: (null|'[^']*'),?\s*\)",
    table,
)

lines = [
    "// Bu dosya resources/scripts/kdbx-cihaz-ornekleri.py ile üretildi; elle",
    "// değiştirilmez. Kaynaklar: test/fixtures/import/kdbx/KAYNAKLAR.md.",
    "",
    "/// Dosya yolu → Base64 içerik.",
    "const kdbxFixtureFiles = <String, String>{",
]
files = sorted({e[0] for e in entries} | {e[2].strip("'") for e in entries if e[2] != "null"})
for path in files:
    data = base64.b64encode((ROOT / path).read_bytes()).decode()
    lines.append(f"  '{path}':")
    lines.append(f"      '{data}',")
lines.append("};")
lines.append("")
lines.append("/// Dosya → (parola, anahtar dosyası, pykeepass'ın dönüştürülmüş anahtarı).")
lines.append(
    "const kdbxDeviceCases = <String, ({String? password, String? keyFile, String? transformed})>{"
)
for path, password, key_file in entries:
    pw = None if password == "null" else password.strip("'")
    kf = None if key_file == "null" else key_file.strip("'")
    try:
        kp = PyKeePass(
            str(ROOT / path),
            password=pw,
            keyfile=str(ROOT / kf) if kf else None,
        )
        transformed = f"'{kp.transformed_key.hex()}'"
    except Exception:  # KDBX 2
        transformed = "null"
    lines.append(f"  '{path}': (")
    lines.append(f"    password: {password},")
    lines.append(f"    keyFile: {key_file},")
    lines.append(f"    transformed: {transformed},")
    lines.append("  ),")
lines.append("};")
OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
print(f"{len(entries)} dosya, {OUT}")
