import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bütün ekranların cam dile geçtiğini kaynak üzerinden denetler: düz
/// `Scaffold` zemini siyah bırakır, `AlertDialog` ve düz alt pencere camsız
/// kalır.
void main() {
  /// Yorum satırları dışındaki kod satırları, dosya yoluyla.
  Iterable<(String, String)> codeLines() sync* {
    final files = [
      ...Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => f.path.replaceAll(r'\', '/').contains('/presentation/'),
          ),
      ...Directory('lib/app').listSync(recursive: true).whereType<File>(),
    ].where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      for (final line in file.readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        yield (path, line);
      }
    }
  }

  String name(String path) => path.split('/').last;

  test('ekranlar KkScaffold kullanıyor', () {
    // Zemini kendisi çizenler: cam iskelet, alttaki menünün kabuğu ve
    // doldurma penceresi.
    const allowed = {
      'kk_backdrop.dart',
      'app_shell.dart',
      'autofill_sheet_frame.dart',
    };
    final offenders = [
      for (final (path, line) in codeLines())
        if (RegExp(r'(?<![A-Za-z])Scaffold\(').hasMatch(line) &&
            !allowed.contains(name(path)))
          '$path: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });

  test('alt pencere yalnızca showKkSheet ile açılıyor', () {
    final offenders = [
      for (final (path, line) in codeLines())
        if (line.contains('showModalBottomSheet(') &&
            name(path) != 'kk_sheet.dart')
          '$path: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });

  test('AlertDialog ve showDialog yok, eski filigran yok', () {
    final offenders = [
      for (final (path, line) in codeLines())
        if (line.contains('AlertDialog') ||
            line.contains('showDialog(') ||
            line.contains('RecordWatermark'))
          '$path: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });
}
