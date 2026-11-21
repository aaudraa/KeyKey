/// Alan adlarını karşılaştırılabilir biçime getirir.
///
/// Tarayıcı formun alan adını ASCII (punycode) olarak bildirir; kullanıcı
/// kayda `bücher.de` yazmış olabilir. İkisi de küçük harfli ASCII'ye
/// çevrilip öyle karşılaştırılır.
abstract final class DomainName {
  static final _asciiLabel = RegExp(r'^[a-z0-9_]([a-z0-9_-]*[a-z0-9_])?$');
  static final _ipv4 = RegExp(r'^[0-9]+(\.[0-9]+){3}$');

  /// Bir adresin alan adı. Şema yoksa `https://` varsayılır. Alan adı
  /// çıkarılamazsa `null`.
  static String? hostOfUrl(String url) {
    var rest = url.trim();
    if (rest.isEmpty) return null;
    final scheme = rest.indexOf('://');
    if (scheme >= 0) rest = rest.substring(scheme + 3);
    final end = rest.indexOf(RegExp('[/?#]'));
    if (end >= 0) rest = rest.substring(0, end);
    // Kullanıcı bilgisi ve kapı numarası atılır.
    final at = rest.lastIndexOf('@');
    if (at >= 0) rest = rest.substring(at + 1);
    if (rest.startsWith('[')) {
      final close = rest.indexOf(']');
      return close < 0 ? null : rest.substring(0, close + 1).toLowerCase();
    }
    final colon = rest.indexOf(':');
    if (colon >= 0) rest = rest.substring(0, colon);
    return normalize(rest);
  }

  /// Küçük harfli ASCII alan adı; geçersizse `null`.
  static String? normalize(String host) {
    var name = host.trim().toLowerCase();
    if (name.endsWith('.')) name = name.substring(0, name.length - 1);
    if (name.isEmpty) return null;
    if (name.startsWith('[') && name.endsWith(']')) return name;
    final labels = <String>[];
    for (final label in name.split('.')) {
      final ascii = label.runes.every((c) => c < 0x80)
          ? label
          : 'xn--${Punycode.encode(label)}';
      if (ascii.length > 63 || !_asciiLabel.hasMatch(ascii)) return null;
      labels.add(ascii);
    }
    final result = labels.join('.');
    return result.length > 253 ? null : result;
  }

  /// IP adresleri alan adı gibi indirgenmez; yalnızca tam eşleşir.
  static bool isIpAddress(String host) =>
      host.startsWith('[') || _ipv4.hasMatch(host);
}

/// RFC 3492 punycode kodlayıcısı; yalnızca bir etiketi kodlar, `xn--`
/// önekini eklemez.
abstract final class Punycode {
  static const _base = 36;
  static const _tMin = 1;
  static const _tMax = 26;
  static const _skew = 38;
  static const _damp = 700;
  static const _initialBias = 72;
  static const _initialN = 128;

  static String encode(String label) {
    final input = label.runes.toList();
    final output = StringBuffer();
    for (final c in input) {
      if (c < 0x80) output.writeCharCode(c);
    }
    final basic = output.length;
    var handled = basic;
    if (basic > 0) output.write('-');

    var n = _initialN;
    var delta = 0;
    var bias = _initialBias;
    while (handled < input.length) {
      var next = 0x10FFFF + 1;
      for (final c in input) {
        if (c >= n && c < next) next = c;
      }
      delta += (next - n) * (handled + 1);
      n = next;
      for (final c in input) {
        if (c < n) delta++;
        if (c != n) continue;
        var q = delta;
        for (var k = _base; ; k += _base) {
          final t = k <= bias
              ? _tMin
              : k >= bias + _tMax
              ? _tMax
              : k - bias;
          if (q < t) break;
          output.writeCharCode(_digit(t + (q - t) % (_base - t)));
          q = (q - t) ~/ (_base - t);
        }
        output.writeCharCode(_digit(q));
        bias = _adapt(delta, handled + 1, first: handled == basic);
        delta = 0;
        handled++;
      }
      delta++;
      n++;
    }
    return output.toString();
  }

  static int _digit(int d) => d < 26 ? 0x61 + d : 0x30 + d - 26;

  static int _adapt(int delta, int points, {required bool first}) {
    var d = first ? delta ~/ _damp : delta ~/ 2;
    d += d ~/ points;
    var k = 0;
    while (d > ((_base - _tMin) * _tMax) ~/ 2) {
      d ~/= _base - _tMin;
      k += _base;
    }
    return k + ((_base - _tMin + 1) * d) ~/ (d + _skew);
  }
}
