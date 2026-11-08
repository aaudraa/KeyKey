// Uygulamaya giren Dart paketlerini sürüm, kaynak ve lisanslarıyla listeler.
//
// Kullanım (repo kökünde):
//   flutter pub deps --json > deps.json
//   node resources/scripts/dart-lisanslari.mjs deps.json
//
// Geliştirme bağımlılıkları (dev_dependencies) ve yalnızca onların getirdiği
// paketler listeye girmez. Lisans, paketin pub önbelleğindeki LICENSE
// dosyasının metninden tanınır; tanınmayan "?" olarak çıkar ve elle bakılır.
// Çıktı Markdown tablosu satırlarıdır.
import fs from 'node:fs';
import path from 'node:path';

const deps = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const byName = Object.fromEntries(deps.packages.map((p) => [p.name, p]));
const root = deps.packages.find((p) => p.kind === 'root');

// Kökün normal bağımlılıklarından ulaşılabilen paketler.
const reachable = new Set();
const queue = [...root.directDependencies];
while (queue.length > 0) {
  const name = queue.pop();
  if (reachable.has(name)) continue;
  reachable.add(name);
  queue.push(...(byName[name].directDependencies ?? []));
}

// pubspec.lock'tan her paketin kaynağı (hosted, sdk).
const source = {};
let current = null;
for (const line of fs.readFileSync('pubspec.lock', 'utf8').split(/\r?\n/)) {
  const name = line.match(/^ {2}([a-z0-9_]+):$/);
  if (name) current = name[1];
  const src = line.match(/^ {4}source: (\w+)/);
  if (src && current) source[current] = src[1];
}

const cache =
  process.env.PUB_CACHE ??
  (process.platform === 'win32'
    ? path.join(process.env.LOCALAPPDATA, 'Pub', 'Cache')
    : path.join(process.env.HOME, '.pub-cache'));

// Bazı paketlerin LICENSE dosyası birden çok lisans içerir (ör. Flutter
// eklentilerinde BSD ve içine alınmış Apache kodu); hepsi yazılır.
function licenseOf(text) {
  const found = [];
  if (/Redistribution and use in source and binary forms/.test(text)) {
    found.push(/Neither the name|names of its/.test(text) ? 'BSD-3-Clause' : 'BSD-2-Clause');
  }
  if (/Permission is hereby granted, free of charge/.test(text)) found.push('MIT');
  if (/Apache License/i.test(text) && /Version 2\.0/.test(text)) found.push('Apache-2.0');
  if (/Permission to use, copy, modify, and\/or distribute/.test(text)) found.push('ISC');
  if (/Mozilla Public License/.test(text)) found.push('MPL-2.0');
  if (/GNU LESSER GENERAL PUBLIC/i.test(text)) found.push('LGPL');
  else if (/GNU GENERAL PUBLIC/i.test(text)) found.push('GPL');
  return found.length > 0 ? found.join(', ') : '?';
}

for (const name of [...reachable].sort()) {
  const pkg = byName[name];
  const src = source[name] ?? '?';
  let license = '?';
  if (src === 'sdk') {
    license = 'BSD-3-Clause (Flutter SDK)';
  } else if (src === 'hosted') {
    const dir = path.join(cache, 'hosted', 'pub.dev', `${name}-${pkg.version}`);
    const file = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING']
      .map((f) => path.join(dir, f))
      .find((f) => fs.existsSync(f));
    license = file ? licenseOf(fs.readFileSync(file, 'utf8')) : 'LICENSE yok';
  }
  const kind = pkg.kind === 'direct' ? 'doğrudan' : 'dolaylı';
  console.log(`| \`${name}\` | ${pkg.version} | ${kind} | ${license} |`);
}
