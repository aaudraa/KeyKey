/// İçe aktarılan özel anahtarların denetimi.
///
/// KeyKey yalnızca ES256 (P-256) passkey'leri kullanır. Başka bir uygulamadan
/// gelen anahtar kasaya girmeden önce PKCS#8 yapısı ve eğrisi denetlenir;
/// anahtarın kendisini Android'in sağlayıcısı imza sırasında okur.
library;

import 'dart:convert';
import 'dart:typed_data';

/// `AlgorithmIdentifier { id-ecPublicKey, prime256v1 }`, DER.
const _p256Algorithm = [
  0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, //
  0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07,
];

/// [der] bir P-256 PKCS#8 `PrivateKeyInfo` mı: sürüm 0, P-256 algoritması ve
/// tam olarak yapının sonuna kadar süren bir özel anahtar dizisi. Dizinin
/// içi de bir `ECPrivateKey` olmalı (bkz. [_isEcPrivateKey]).
bool isP256Pkcs8(List<int> der) {
  final outer = _header(der, 0, 0x30);
  if (outer == null || outer.end != der.length) return false;
  var at = outer.start;
  // Sürüm: INTEGER 0.
  if (!_startsWith(der, at, const [0x02, 0x01, 0x00])) return false;
  at += 3;
  if (!_startsWith(der, at, _p256Algorithm)) return false;
  at += _p256Algorithm.length;
  final key = _header(der, at, 0x04);
  // İsteğe bağlı öznitelikler KeePassXC ve Bitwarden'da yok; sonda başka
  // bayt kalmamalı.
  return key != null &&
      key.end == der.length &&
      _isEcPrivateKey(der.sublist(key.start, key.end));
}

/// RFC 5915 `ECPrivateKey`: sürüm 1 ve sıfır olmayan gizli sayı. RFC 32
/// bayt ister ama bazı araçlar baştaki sıfırları atar ya da bir sıfır
/// ekler; Android'in sağlayıcısı bunları da kabul ettiği için 1-32 bayt ve
/// başı sıfır olan 33 bayt geçer. Ardından gelen isteğe bağlı eğri ve açık
/// anahtar alanlarına bakılmaz; eğri dıştaki algoritmada zaten denetlendi.
bool _isEcPrivateKey(List<int> der) {
  final outer = _header(der, 0, 0x30);
  if (outer == null || outer.end != der.length) return false;
  var at = outer.start;
  if (!_startsWith(der, at, const [0x02, 0x01, 0x01])) return false;
  at += 3;
  final secret = _header(der, at, 0x04);
  if (secret == null) return false;
  var bytes = der.sublist(secret.start, secret.end);
  if (bytes.length == 33 && bytes.first == 0) bytes = bytes.sublist(1);
  return bytes.isNotEmpty && bytes.length <= 32 && bytes.any((b) => b != 0);
}

/// `-----BEGIN PRIVATE KEY-----` PEM'inin DER'i; P-256 PKCS#8 değilse ya da
/// okunamıyorsa `null`.
Uint8List? p256Pkcs8FromPem(String pem) {
  final match = _pem.firstMatch(pem);
  if (match == null) return null;
  final body = match.group(1)!.replaceAll(RegExp(r'\s'), '');
  final Uint8List der;
  try {
    der = base64.decode(body);
  } on FormatException {
    return null;
  }
  return isP256Pkcs8(der) ? der : null;
}

final _pem = RegExp(
  r'-----BEGIN PRIVATE KEY-----([A-Za-z0-9+/=\s]*)-----END PRIVATE KEY-----',
);

bool _startsWith(List<int> bytes, int at, List<int> prefix) {
  if (at + prefix.length > bytes.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[at + i] != prefix[i]) return false;
  }
  return true;
}

/// [at]'taki DER öğesinin içeriğinin başı ve sonu; etiket [tag] değilse ya da
/// uzunluk verinin dışına taşıyorsa `null`. Uzunluk en çok iki bayt.
({int start, int end})? _header(List<int> der, int at, int tag) {
  if (at + 2 > der.length || der[at] != tag) return null;
  final first = der[at + 1];
  int length;
  var start = at + 2;
  if (first < 0x80) {
    length = first;
  } else if (first == 0x81 || first == 0x82) {
    final count = first - 0x80;
    if (start + count > der.length) return null;
    length = 0;
    for (var i = 0; i < count; i++) {
      length = (length << 8) | der[start + i];
    }
    start += count;
  } else {
    return null;
  }
  final end = start + length;
  return end > der.length ? null : (start: start, end: end);
}
