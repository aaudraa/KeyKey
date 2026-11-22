// GEÇİCİ TANI: Linux CI'da meşgul bekleme neden çalışmıyor? Birleştirilmez.
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('tanı', () async {
    final dir = Directory.systemTemp.createTempSync('kk_tani_');
    final path = '${dir.path}/t.db';
    sqlite.sqlite3.open(path)
      ..execute('CREATE TABLE t (x)')
      ..close();
    final out = StringBuffer()
      ..writeln('sürüm ${sqlite.sqlite3.version}')
      ..writeln(options());

    for (final mode in ['ayrı isolate', 'ayrı isolate, okuyucu önce açık']) {
      final events = ReceivePort();
      final log = <String>[];
      final sw = Stopwatch()..start();
      sqlite.Database? early;
      if (mode.contains('önce')) {
        early = sqlite.sqlite3.open(path)
          ..execute('PRAGMA busy_timeout = 5000');
      }
      final done = events.listen((m) => log.add('tutucu $m'));
      final first = ReceivePort();
      await Isolate.spawn(_hold, (path, first.sendPort, events.sendPort));
      await first.first;
      log.add('kilit alındı ${sw.elapsedMilliseconds}');
      final reader =
          early ??
          (sqlite.sqlite3.open(path)..execute('PRAGMA busy_timeout = 5000'));
      final t = sw.elapsedMilliseconds;
      try {
        final v = reader.userVersion;
        log.add('okuma $v tamam ${sw.elapsedMilliseconds - t} ms bekledi');
      } on sqlite.SqliteException catch (e) {
        log.add('okuma HATA ${sw.elapsedMilliseconds - t} ms sonra: $e');
      }
      reader.close();
      await Future<void>.delayed(const Duration(seconds: 1));
      await done.cancel();
      out.writeln('[$mode] ${log.join(' | ')}');
    }
    if (!Platform.isWindows) {
      final usleep = DynamicLibrary.process()
          .lookupFunction<Int32 Function(Uint32), int Function(int)>('usleep');
      final sw = Stopwatch()..start();
      var interrupted = 0;
      for (var i = 0; i < 10; i++) {
        if (usleep(100000) != 0) interrupted++;
      }
      out.writeln(
        '10 x usleep: ${sw.elapsedMilliseconds} ms, kesilen $interrupted',
      );
    }
    dir.deleteSync(recursive: true);
    fail(out.toString());
  });
}

void _hold((String, SendPort, SendPort) args) {
  final (path, first, events) = args;
  final sw = Stopwatch()..start();
  final db = sqlite.sqlite3.open(path)..execute('BEGIN EXCLUSIVE');
  first.send(null);
  sleep(const Duration(milliseconds: 500));
  events.send('uyandı ${sw.elapsedMilliseconds}');
  db.execute('COMMIT');
  events.send('commit ${sw.elapsedMilliseconds}');
  db.close();
}

String options() {
  final db = sqlite.sqlite3.openInMemory();
  final rows = db.select('PRAGMA compile_options');
  final wanted = RegExp('THREAD|USLEEP|LOCK|BUSY');
  final picked = [
    for (final r in rows)
      if (wanted.hasMatch('${r.values.single}')) '${r.values.single}',
  ];
  db.close();
  return 'seçenekler ${picked.join(',')}';
}
