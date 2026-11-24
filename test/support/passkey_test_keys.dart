/// İçe aktarma testlerinin deneme anahtarları; `openssl genpkey` ile
/// üretildi, hiçbir hesaba bağlı değil.
library;

/// P-256 özel anahtarı, PKCS#8 PEM (KeePassXC'in yazdığı biçim).
const p256Pem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg86InM7RDUMpT8jbV
6Z8YlPgv/9sOrADJZOSnNNBK5LihRANCAAQ6SIrHKnz+NLoniD2EEw/xCrpA4xCb
UNtzCjinNvL+Pf8KspKuTlf44fVQ+GYUCWRnhmMqG0O9zM7yFyT39ynj
-----END PRIVATE KEY-----
''';

/// Aynı anahtar, PKCS#8 DER'in dolgusuz base64url'i (Bitwarden'ın
/// `keyValue`'su).
const p256Pkcs8B64Url =
    'MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg86InM7RDUMpT8jbV6Z8YlPgv'
    '_9sOrADJZOSnNNBK5LihRANCAAQ6SIrHKnz-NLoniD2EEw_xCrpA4xCbUNtzCjinNvL-Pf8K'
    'spKuTlf44fVQ-GYUCWRnhmMqG0O9zM7yFyT39ynj';

/// P-384 özel anahtarı, PKCS#8 DER'in standart base64'ü; KeyKey bunu
/// desteklemez.
const p384Pkcs8B64 =
    'MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDDQetsDeZSucVsuylkrHlEfOvTw'
    'dPc2S83nkiGl2kjYmL0D7G5quOk2HHdduP4chhKhZANiAAR0pWUPfXE1vV6yXbnaQPS4nI2B'
    'BBWDYB2izVBj3ZhIyX/AawEGhrOetYlc+YtOA07Zbbrr5opdZGhJ5PxuBAxno7ify5NH9rNF'
    'JHZjzstZjhRuzW8Y7B7d5lljyoR5vS8=';
