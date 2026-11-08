// memory-scan.sh'nin yardımcısı: gzip'li bellek dökümünde değerleri arar.
//
// Kullanım: node memory-search.mjs <döküm.gz> <aranacaklar>
//
// Her değer UTF-8 (ASCII değerlerde Latin-1 ile aynı; Dart'ın tek baytlık
// dizeleri) ve UTF-16LE (Java ve Dart'ın iki baytlık dizeleri) olarak,
// büyük küçük harf ayrılarak aranır. Döküm akış halinde okunur; parçalar
// arasında kalan eşleşmeler için her parçanın sonu bir sonrakine eklenir.
// Değerler yazılmaz, yalnızca aranacaklar dosyasındaki satırları ve kaç kez
// geçtikleri.
import fs from 'node:fs';
import zlib from 'node:zlib';

const [dump, needlesPath] = process.argv.slice(2);
const needles = fs
  .readFileSync(needlesPath, 'utf8')
  .split(/\r?\n/)
  .map((text, index) => ({ text: text.trim(), line: index + 1 }))
  .filter(({ text }) => text && !text.startsWith('#'));

const patterns = needles.map(({ text: needle, line }) => ({
  line,
  forms: [Buffer.from(needle, 'utf8'), Buffer.from(needle, 'utf16le')],
  counts: [0, 0],
}));
const overlap = Math.max(...patterns.flatMap((p) => p.forms.map((f) => f.length))) - 1;

let tail = Buffer.alloc(0);
let total = 0;
const stream = fs.createReadStream(dump).pipe(zlib.createGunzip());
stream.on('data', (chunk) => {
  total += chunk.length;
  const buffer = Buffer.concat([tail, chunk]);
  // Yalnızca bu parçada başlayan eşleşmeler sayılır, kuyruktakiler önceden sayıldı.
  const start = tail.length;
  for (const pattern of patterns) {
    pattern.forms.forEach((form, index) => {
      let at = buffer.indexOf(form, Math.max(0, start - form.length + 1));
      while (at !== -1) {
        if (at + form.length > start) pattern.counts[index]++;
        at = buffer.indexOf(form, at + 1);
      }
    });
  }
  tail = buffer.subarray(Math.max(0, buffer.length - overlap));
});
stream.on('end', () => {
  console.log(`Döküm: ${Math.round(total / 1048576)} MB.`);
  let hits = 0;
  for (const pattern of patterns) {
    const [utf8, utf16] = pattern.counts;
    if (utf8 + utf16 === 0) continue;
    hits++;
    console.log(
      `  ${String(pattern.line).padStart(3)}. satırdaki değer: ` +
        `${utf8} kez (UTF-8), ${utf16} kez (UTF-16)`,
    );
  }
  console.log(hits ? `SONUÇ: ${hits} değer bellekte bulundu.` : 'SONUÇ: hiçbiri bulunmadı.');
  process.exitCode = hits ? 1 : 0;
});
