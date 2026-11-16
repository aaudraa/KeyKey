#!/usr/bin/env python3
"""F-Droid'in okuduğu Fastlane açıklamalarını ve tarif dosyasını denetler.

Denetlenenler: iki dilde zorunlu dosyalar ve uzunluk sınırları, simge boyutu,
ekran görüntüleri, pubspec.yaml'daki sürümün changelog'u, yayın varlık adının
tarifteki Binaries adresiyle uyumu ve tarifteki etiket deseninin deneme
etiketlerini dışarıda bırakması. Yalnızca standart kütüphane kullanır.

Kullanım: python3 resources/scripts/check-fastlane.py   (repo kökünden)
Hata yoksa çıkış 0; her hata için "HATA: <yer>: <neden>" ve çıkış 1.
Ayrıntılar: resources/docs/f-droid.md
"""

import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FASTLANE = ROOT / "fastlane" / "metadata" / "android"
RECIPE = ROOT / "resources" / "f-droid" / "io.github.aaudraa.keykey.yml"
WORKFLOW = ROOT / ".github" / "workflows" / "yayin.yml"
PUBSPEC = ROOT / "pubspec.yaml"

LOCALES = ("en-US", "tr-TR")
# (dosya, en az, en çok) karakter
TEXTS = (
    ("title.txt", 1, 30),
    ("short_description.txt", 1, 80),
    ("full_description.txt", 1, 4000),
)
CHANGELOG_MAX_BYTES = 500
ICON_SIZE = (512, 512)
MIN_SCREENSHOTS = 4
BINARIES = "https://github.com/aaudraa/KeyKey/releases/download/v%v/keykey-%v.apk"
TAGS_ACCEPT = ("v1.0.1", "v12.3.4")
TAGS_REJECT = ("v1.0.1-deneme.1", "v1.1.0-rc.1", "deneme-siyah-beyaz-1", "v1.0")

errors: list[str] = []


def err(where: Path | str, why: str) -> None:
    if isinstance(where, Path):
        where = where.relative_to(ROOT).as_posix()
    errors.append(f"HATA: {where}: {why}")


def png_size(path: Path) -> tuple[int, int] | None:
    data = path.read_bytes()[:24]
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", data[16:24])


def is_image(path: Path) -> bool:
    head = path.read_bytes()[:8]
    return head == b"\x89PNG\r\n\x1a\n" or head[:3] == b"\xff\xd8\xff"


def version_code() -> str | None:
    m = re.search(r"^version:\s*[^+\s]+\+(\d+)\s*$", PUBSPEC.read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else None


def check_locale(locale: str, code: str | None) -> None:
    base = FASTLANE / locale
    if not base.is_dir():
        err(base, "dil klasörü yok")
        return
    for name, lo, hi in TEXTS:
        f = base / name
        if not f.is_file():
            err(f, "yok")
            continue
        n = len(f.read_text(encoding="utf-8").strip())
        if not lo <= n <= hi:
            err(f, f"{n} karakter, {lo}-{hi} olmalı")
    icon = base / "images" / "icon.png"
    if not icon.is_file():
        err(icon, "yok")
    elif png_size(icon) != ICON_SIZE:
        err(icon, f"PNG ve {ICON_SIZE[0]}x{ICON_SIZE[1]} olmalı, {png_size(icon)}")
    shots_dir = base / "images" / "phoneScreenshots"
    shots = sorted(shots_dir.glob("*")) if shots_dir.is_dir() else []
    for s in shots:
        if s.suffix.lower() not in (".png", ".jpg", ".jpeg") or not is_image(s):
            err(s, "yalnızca PNG ya da JPG olabilir")
    if len(shots) < MIN_SCREENSHOTS:
        err(shots_dir, f"{len(shots)} ekran görüntüsü, en az {MIN_SCREENSHOTS}")
    changelogs = base / "changelogs"
    for c in sorted(changelogs.glob("*.txt")) if changelogs.is_dir() else []:
        if not re.fullmatch(r"\d+", c.stem):
            err(c, "adı versionCode olmalı (ör. 4.txt)")
        size = len(c.read_bytes())
        if size > CHANGELOG_MAX_BYTES:
            err(c, f"{size} bayt, en çok {CHANGELOG_MAX_BYTES}")
    if code is not None and not (changelogs / f"{code}.txt").is_file():
        err(changelogs / f"{code}.txt", "pubspec.yaml'daki sürümün changelog'u yok")


def check_recipe() -> None:
    if not RECIPE.is_file():
        err(RECIPE, "yok")
        return
    text = RECIPE.read_text(encoding="utf-8")
    m = re.search(r"^Binaries:\s*(\S+)\s*$", text, re.M)
    if not m or m.group(1) != BINARIES:
        err(RECIPE, f"Binaries satırı {BINARIES} olmalı")
    m = re.search(r"^UpdateCheckMode:\s*Tags\s+(\S+)\s*$", text, re.M)
    if not m:
        err(RECIPE, "UpdateCheckMode: Tags <desen> yok")
        return
    pattern = re.compile(m.group(1))
    for tag in TAGS_ACCEPT:
        if not pattern.search(tag):
            err(RECIPE, f"etiket deseni {tag} sürümünü kaçırıyor")
    for tag in TAGS_REJECT:
        if pattern.search(tag):
            err(RECIPE, f"etiket deseni {tag} etiketini de alıyor")


def check_workflow() -> None:
    text = WORKFLOW.read_text(encoding="utf-8")
    if 'dist/keykey-${VERSION}.apk' not in text:
        err(WORKFLOW, "APK artık dist/keykey-${VERSION}.apk adıyla yayımlanmıyor; tarifteki Binaries kırılır")


def main() -> int:
    code = version_code()
    if code is None:
        err(PUBSPEC, "version: x.y.z+N satırı okunamadı")
    for locale in LOCALES:
        check_locale(locale, code)
    check_recipe()
    check_workflow()
    for e in errors:
        print(e)
    if not errors:
        print("Fastlane açıklamaları ve F-Droid tarifi uygun.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
