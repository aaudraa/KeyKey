// test/fixtures/crypto/vault-v1.json dosyasının cihaz testleri için kopyası.
// Cihazda dosya sistemi okunamadığı için sabit olarak tutuluyor. Yalnızca deneme
// verisi içerir ve değiştirilmemelidir.
// ignore_for_file: lines_longer_than_80_chars

const fixtureHeaderJson =
    '''{"version":1,"vaultId":"2cl6YPbwBfkrOxoos0Qoww==","kdf":{"algorithm":"argon2id13","opsLimit":3,"memLimit":67108864,"salt":"Av/lRQzGqhEtzGual3VLhg=="},"slots":{"password":{"nonce":"CCEthkMe8CUFACBYHe0R/9YE+bIjONIN","cipherText":"VEJV7762Z+l0xmJCF95a0fwvrKzpwtz3b//bjUgCX6tKL/F2fJgWa4S2nER+AmDX"},"recovery":{"nonce":"cR0Ac491+bw8nbV8ghyBAl/DhrVWgGKp","cipherText":"AWTXeluu+v3l6CmJpCcM32YGrKbIvZCYySC24IKlJrMuRQlI5x+ov/riyC4yUIFF"}}}''';
const fixturePassword = '''deneme-parolası-ığüşöç''';
const fixtureRecoveryKey =
    '''AZPTX-1VXQ0-AN66H-N8YP7-QBDJ8-VKH44-N5STW-97J79-4TC2Z-VV7PF-0VFER''';
const fixtureVaultKey = '''DeXxkaQdtnJzNoBqtB/qtc2rQxhzcfnxi/aT1UbC9os=''';
const fixtureRecordId = '''AAECAwQFBgcICQoLDA0ODw==''';
const fixtureRecordType = '''login''';
const fixtureRecordPlainText =
    '''{"site":"ornek.com","parola":"deneme-ığüşöç"}''';
const fixtureRecordBlob =
    '''Afu0lFBHa/QmFEeYwbi1AxKU3toYiYjGN6EErjTQxD8VFF8elBCEmu/YcS+ocZlJF5V9cMk9yiPm4tJ3UEeckZZRIB+crBswz7/Y17a76F3EhN/4u+PSZd8Nwy1dtRvkcdmxJx0khHTkslRYBhUYC7ulhQlc4CqKfT2Q41gIJF0dFZPxbarHOwUpG8ffXKkvUOU5MTSUGcqOY4TFu3o0mjc6GnI2ZBYF/pjRX4KVFNUQI1CgQiC4/fJUNBeJM8YUk3Y2fxmDQlY/LL2BGbHnUmdOb/MVTafsyL4jybt4jQ9xzbcXYRAnrCt3fiJ8ezAbjtmz8fjfdvkx1Bk4fVlH5CDIWOPFNHNMty0M5e2imbpu4llji0vK557o3g4/Df93I3Pp9vgL1GMB''';
