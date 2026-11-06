import 'dart:typed_data';

/// RFC 4648 Base32. 2FA gizli anahtarları bu biçimde taşınır.
///
/// İki okuma yolu vardır: kayıtlarda yalnızca bizim yazdığımız biçim kabul
/// edilir ([decodeCanonical]), kullanıcının yazdığı veya bağlantıdan gelen
/// metinde ise yaygın yazım farkları hoş görülür ([decodeLenient]).
abstract final class Base32 {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Türkçe klavyede Shift ile yazılan I: U+0130.
  static const _dottedCapitalI = 0x130;

  /// Büyük harf ve dolgusuz yazar.
  static String encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | (byte & 0xff);
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.writeCharCode(_alphabet.codeUnitAt((buffer >> bits) & 0x1f));
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) {
      out.writeCharCode(_alphabet.codeUnitAt((buffer << (5 - bits)) & 0x1f));
    }
    return out.toString();
  }

  /// Yalnızca [encode]'un üreteceği metni kabul eder: büyük harf, dolgu ve
  /// boşluk yok, geçerli uzunluk ve artan bitler sıfır.
  ///
  /// Uymayan metinde [FormatException] fırlatır.
  static Uint8List decodeCanonical(String text) =>
      _decode(text, canonical: true);

  /// Küçük harf, boşluk, tire ve sondaki `=` dolgusunu kabul eder. Türkçe
  /// klavyenin noktalı büyük İ harfi I sayılır. Bir bayta tamamlanmayan artan
  /// bitler atılır.
  ///
  /// Alfabe dışında karakter varsa [FormatException] fırlatır.
  static Uint8List decodeLenient(String text) {
    final cleaned = StringBuffer();
    for (final rune in text.runes) {
      if (rune == 0x20 || rune == 0x2d || rune == 0x09) continue;
      cleaned.writeCharCode(rune == _dottedCapitalI ? 0x49 : rune);
    }
    var body = cleaned.toString().toUpperCase();
    final paddingStart = body.indexOf('=');
    if (paddingStart >= 0) {
      if (body.substring(paddingStart).replaceAll('=', '').isNotEmpty) {
        throw const FormatException('Dolgu yalnızca sonda olabilir.');
      }
      body = body.substring(0, paddingStart);
    }
    return _decode(body, canonical: false);
  }

  /// [decodeLenient]'in kabul etmeyeceği ilk karakter, yoksa `null`.
  ///
  /// Boşluk, tire, sekme ve `=` atlanır; harfler büyük harfe çevrilerek
  /// denetlenir. Kullanıcıya hangi karakterin yanlış olduğunu söylemek için.
  static String? firstForeignCharacter(String text) {
    for (final rune in text.runes) {
      if (rune == 0x20 || rune == 0x2d || rune == 0x09 || rune == 0x3d) {
        continue;
      }
      if (rune == _dottedCapitalI) continue;
      final character = String.fromCharCode(rune);
      if (!_alphabet.contains(character.toUpperCase())) return character;
    }
    return null;
  }

  static Uint8List _decode(String text, {required bool canonical}) {
    // 8 karakter 5 bayttır. Kalan karakter sayısı 1, 3 veya 6 olamaz, çünkü
    // hiçbir bayt sayısı bu kadar karakter üretmez.
    final remainder = text.length % 8;
    if (canonical && (remainder == 1 || remainder == 3 || remainder == 6)) {
      throw const FormatException('Geçersiz uzunluk.');
    }
    final out = Uint8List(text.length * 5 ~/ 8);
    var buffer = 0;
    var bits = 0;
    var index = 0;
    for (var i = 0; i < text.length; i++) {
      final value = _alphabet.indexOf(text[i]);
      if (value < 0) {
        throw const FormatException('Base32 alfabesinde olmayan karakter.');
      }
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out[index++] = (buffer >> bits) & 0xff;
        buffer &= (1 << bits) - 1;
      }
    }
    if (canonical && buffer != 0) {
      throw const FormatException('Artan bitler sıfır değil.');
    }
    return out;
  }
}
