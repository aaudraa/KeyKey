/// RFC 4180 CSV yazıcısı.
///
/// Virgül, tırnak, satır sonu veya baştaki ve sondaki boşluğu içeren alanlar
/// tırnağa alınır, içteki tırnaklar ikilenir. Satırlar CRLF ile biter.
/// Hücreler formül kaçışından geçirilmez: dosya başka bir parola
/// yöneticisine verilmek içindir, `=` ile başlayan bir parola olduğu gibi
/// kalmalıdır.
abstract final class CsvWriter {
  static String write(Iterable<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer
        ..writeAll(row.map(_field), ',')
        ..write('\r\n');
    }
    return buffer.toString();
  }

  static String _field(String value) {
    final needsQuotes =
        value.contains(RegExp('[,"\r\n]')) || value.trim() != value;
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
