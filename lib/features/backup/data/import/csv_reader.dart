/// CSV metni RFC 4180'e uymuyor: kapanmayan tırnak veya tırnaktan sonra
/// beklenmeyen karakter.
final class CsvFormatException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'CsvFormatException: $message';
}

/// RFC 4180 CSV okuyucu.
///
/// Alanlar virgülle ayrılır; tırnaklı alanda virgül, satır sonu ve `""`
/// (tek tırnak) bulunabilir. Satır sonu `\r\n`, `\n` veya `\r` olabilir.
/// Baştaki UTF-8 BOM atlanır. Tamamen boş satırlar atlanır. Başka
/// uygulamaların dosyaları güvenilmeyen veri sayıldığı için satır ve alan
/// sayısı sınırlıdır.
abstract final class CsvReader {
  static const maxRows = 100000;
  static const maxFields = 64;

  static List<List<String>> read(String text) {
    final input = text.startsWith('﻿') ? text.substring(1) : text;
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    // Tırnaklı alan kapandıktan sonra yalnızca ayırıcı gelebilir.
    var afterQuote = false;
    // Satırda en az bir karakter veya ayırıcı görüldü mü.
    var rowStarted = false;

    void endField() {
      if (row.length >= maxFields) {
        throw const CsvFormatException('Satırda çok fazla alan var.');
      }
      row.add(field.toString());
      field.clear();
      afterQuote = false;
    }

    void endRow() {
      if (rowStarted) {
        endField();
        if (rows.length >= maxRows) {
          throw const CsvFormatException('Çok fazla satır var.');
        }
        rows.add(row);
      }
      row = <String>[];
      rowStarted = false;
    }

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
            afterQuote = true;
          }
        } else {
          field.write(char);
        }
        continue;
      }
      switch (char) {
        case ',':
          rowStarted = true;
          endField();
        case '\r' || '\n':
          if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
            i++;
          }
          endRow();
        case '"':
          if (afterQuote || field.isNotEmpty) {
            throw const CsvFormatException('Alanın ortasında tırnak var.');
          }
          rowStarted = true;
          inQuotes = true;
        default:
          if (afterQuote) {
            throw const CsvFormatException('Tırnaktan sonra karakter var.');
          }
          rowStarted = true;
          field.write(char);
      }
    }
    if (inQuotes) throw const CsvFormatException('Tırnak kapanmamış.');
    endRow();
    return rows;
  }
}
