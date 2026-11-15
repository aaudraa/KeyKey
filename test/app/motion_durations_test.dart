import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ekranlar süre yazmaz; hareket süreleri `KkMotion`'dan gelir. İzin
/// listesi hareket olmayan süreler içindir.
const _allowed = {
  // 2FA: sonraki kodun gösterilmeye başlandığı kalan süre.
  'otp_code_tile.dart': ['nextCodeThreshold'],
  // 2FA: halkanın uyarı rengine döndüğü kalan süre.
  'otp_ring.dart': ['warningThreshold'],
  // Kameranın iki okuma arasındaki bekleme süresi.
  'qr_scan_screen.dart': ['scanDelay'],
  // Yanlış parola beklemesinin saniyelik sayacı.
  'lock_screen.dart': ['Timer.periodic', '_wait - const Duration'],
};

void main() {
  test('hareket süreleri yalnızca KkMotion içinde', () {
    final dirs = [
      Directory('lib/app'),
      for (final f in Directory('lib/features').listSync())
        if (f is Directory) Directory('${f.path}/presentation'),
    ];
    final pattern = RegExp(r'Duration\((milliseconds|seconds):');
    final offenders = <String>[];
    for (final dir in dirs.where((d) => d.existsSync())) {
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final name = file.uri.pathSegments.last;
        if (name == 'kk_motion.dart') continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!pattern.hasMatch(line)) continue;
          final ok = (_allowed[name] ?? const []).any(line.contains);
          if (!ok) offenders.add('$name:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
