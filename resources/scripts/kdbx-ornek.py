"""KeePass içe aktarma testleri için örnek .kdbx dosyası üretir.

Kullanım (pykeepass 4.2.0 gerekir):

    python resources/scripts/kdbx-ornek.py test/fixtures/import/kdbx/keykey/keykey_ornek.kdbx

Parola `keykey`. Dosya pykeepass'ın kendi yazıcısıyla oluşur; KeyKey'in
okuyucusundan bağımsız bir uygulama. Her çalıştırmada tuzlar değiştiği için
dosyanın baytları değişir, içeriği aynı kalır.
"""

import sys

from pykeepass import create_database

kp = create_database(sys.argv[1], password="keykey")
root = kp.root_group
mail = kp.add_group(root, "E-posta")
work = kp.add_group(mail, "İş")

base = kp.add_entry(work, "GitHub", "furkan", "gizli-parola", url="https://github.com/login",
                    notes="birinci satır\r\nikinci satır")
base.otp = "otpauth://totp/GitHub:furkan?secret=JBSWY3DPEHPK3PXP&issuer=GitHub"
base.set_custom_property("KP2A_URL", "https://gist.github.com")
base.set_custom_property("KP2A_URL_1", "androidapp://com.github.android")
base.set_custom_property("Kurtarma kodu", "1234-5678", protect=True)
base.set_custom_property("Açık alan", "görünür")
base.set_custom_property("KPEX_PASSKEY_USERNAME", "iç alan")

kp2 = kp.add_entry(mail, "Posta", "furkan@example.com", "posta-parola", url="mail.example.com")
kp2.set_custom_property("TimeOtp-Secret-Base32", "GEZDGNBVGY3TQOJQ")
kp2.set_custom_property("TimeOtp-Algorithm", "HMAC-SHA-256")
kp2.set_custom_property("TimeOtp-Length", "8")
kp2.set_custom_property("TimeOtp-Period", "60")

steam = kp.add_entry(root, "Steam", "keykey", "steam-parola", url="https://store.steampowered.com")
steam.set_custom_property("TOTP Seed", "JBSWY3DPEHPK3PXP")
steam.set_custom_property("TOTP Settings", "30;S")

kp.add_entry(root, "Başvuru", "{REF:U@I:" + base.uuid.hex.upper() + "}",
             "{REF:P@I:" + base.uuid.hex.upper() + "}")

kp.add_entry(root, "Wi-Fi notu", "", "", notes="ağ: keykey\nşifre kutuda")
kp.add_entry(root, "", "", "")

with_file = kp.add_entry(root, "Ekli", "ekli", "ekli-parola")
binary_id = kp.add_binary(b"merhaba")
with_file.add_attachment(binary_id, "not.txt")

old = kp.add_entry(root, "Eski hesap", "eski", "eski-parola")
kp.trash_entry(old)

kp.save()
