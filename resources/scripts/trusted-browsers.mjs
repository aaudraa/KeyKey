// Güvenilen tarayıcı listesini Google'ın ayrıcalıklı uygulamalar listesinden
// üretir.
//
// Kullanım:
//   curl -sSfL -o apps.json https://www.gstatic.com/gpm-passkeys-privileged-apps/apps.json
//   node resources/scripts/trusted-browsers.mjs apps.json
//
// Çıktı: android/app/src/main/kotlin/io/github/aaudraa/keykey/autofill/TrustedBrowserList.kt
// Kurallar güvenlik tasarımı belgesinin "Eşleştirme" bölümünde.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

const output =
  'android/app/src/main/kotlin/io/github/aaudraa/keykey/autofill/TrustedBrowserList.kt';

// Listede olup tarayıcı olmayanlar. Bunların bildirdiği alan adına
// güvenilmez: Google Play Hizmetleri ve kimlik bilgisi sağlayıcıları.
const excluded = new Set([
  'com.google.android.gms',
  'com.fido.fido2client',
  'com.oplus.credential',
]);

const packagePattern = /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/;
const fingerprintPattern = /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/;

const source = process.argv[2];
if (!source) {
  console.error('Kullanım: node resources/scripts/trusted-browsers.mjs apps.json');
  process.exit(2);
}
const bytes = readFileSync(source);
const json = JSON.parse(bytes.toString('utf8'));
if (!Array.isArray(json.apps)) throw new Error('Beklenmeyen biçim: apps yok.');

const browsers = new Map();
for (const app of json.apps) {
  if (app.type !== 'android') continue;
  const name = app.info?.package_name;
  if (typeof name !== 'string' || !packagePattern.test(name)) {
    throw new Error(`Geçersiz paket adı: ${name}`);
  }
  if (excluded.has(name)) continue;
  const digests = new Set();
  for (const signature of app.info.signatures ?? []) {
    // Test sürümlerinin (userdebug) imzaları alınmaz.
    if (signature.build !== 'release') continue;
    const fingerprint = signature.cert_fingerprint_sha256;
    if (!fingerprintPattern.test(fingerprint)) {
      throw new Error(`Geçersiz imza özeti: ${name} ${fingerprint}`);
    }
    digests.add(fingerprint.replaceAll(':', '').toLowerCase());
  }
  if (digests.size === 0) continue;
  const known = browsers.get(name) ?? new Set();
  for (const digest of digests) known.add(digest);
  browsers.set(name, known);
}

const sha256 = createHash('sha256').update(bytes).digest('hex');
const names = [...browsers.keys()].sort();
const entries = names
  .map((name) => {
    const digests = [...browsers.get(name)].sort();
    const lines = digests.map((d) => `        "${d}",`).join('\n');
    return `    "${name}" to setOf(\n${lines}\n    ),`;
  })
  .join('\n');

const kotlin = `package io.github.aaudraa.keykey.autofill

// Bu dosya resources/scripts/trusted-browsers.mjs ile üretildi; elle
// düzenlenmez.
// Kaynak: https://www.gstatic.com/gpm-passkeys-privileged-apps/apps.json
// Kaynağın SHA-256 özeti: ${sha256}
// ${names.length} uygulama; yalnızca yayın sürümü imzaları.

/** Paket adı -> izin verilen imza sertifikası SHA-256 özetleri. */
internal val TRUSTED_BROWSERS: Map<String, Set<String>> = mapOf(
${entries}
)
`;
writeFileSync(output, kotlin);
console.log(`${names.length} uygulama yazıldı: ${output}`);
