// APK imza bloğundaki parçaları listeler; bilinmeyen ya da istenmeyen bir
// parça varsa 1 ile çıkar. check-release-apk.sh çağırır.
//
// Kullanım: node resources/scripts/imza-blogu.mjs <apk>
//
// AGP'nin Google için şifrelediği bağımlılık listesi (0x504b4453) her
// derlemede farklı çıktığı için APK'yı yeniden üretilemez yapıyordu;
// build.gradle.kts'teki dependenciesInfo ile kapalı. Bkz. resources/docs/yayin.md
import { readFileSync } from 'node:fs';

const known = new Map([
  [0x7109871a, 'APK İmza Şeması v2'],
  [0xf05368c0, 'APK İmza Şeması v3'],
  [0x1b93ad61, 'APK İmza Şeması v3.1'],
  [0x42726577, 'dolgu'],
]);
const forbidden = new Map([[0x504b4453, 'şifreli bağımlılık listesi (AGP)']]);

const path = process.argv[2];
if (!path) {
  console.error('Kullanım: node imza-blogu.mjs <apk>');
  process.exit(2);
}
const apk = readFileSync(path);
let eocd = apk.length - 22;
while (eocd >= 0 && apk.readUInt32LE(eocd) !== 0x06054b50) eocd--;
if (eocd < 0) {
  console.error('HATA: zip dizini bulunamadı.');
  process.exit(1);
}
const centralDirectory = apk.readUInt32LE(eocd + 16);
if (apk.toString('latin1', centralDirectory - 16, centralDirectory) !== 'APK Sig Block 42') {
  console.error('HATA: APK imza bloğu yok.');
  process.exit(1);
}
const size = Number(apk.readBigUInt64LE(centralDirectory - 24));
let offset = centralDirectory - size;
const end = centralDirectory - 24;
let failed = false;
while (offset < end) {
  const length = Number(apk.readBigUInt64LE(offset));
  const id = apk.readUInt32LE(offset + 8);
  const hex = `0x${id.toString(16).padStart(8, '0')}`;
  if (forbidden.has(id)) {
    console.log(`HATA: imza bloğunda ${forbidden.get(id)} (${hex}).`);
    failed = true;
  } else if (known.has(id)) {
    console.log(`İmza bloğu: ${known.get(id)} (${hex}), ${length - 4} bayt.`);
  } else {
    console.log(`HATA: imza bloğunda bilinmeyen parça ${hex}, ${length - 4} bayt.`);
    failed = true;
  }
  offset += 8 + length;
}
process.exit(failed ? 1 : 0);
