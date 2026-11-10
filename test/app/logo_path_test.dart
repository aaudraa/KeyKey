import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/keykey_logo.dart';

void main() {
  final svg = File('resources/design/keykey-simge.svg').readAsStringSync();

  test('uygulama simgesindeki K, uygulamadaki logonun yoluyla aynı', () {
    final d = RegExp(r'<path[^>]*\sd="([^"]+)"').firstMatch(svg)?.group(1);
    expect(d, KeyKeyLogo.pathData);
  });

  test('Android ön katmanı ve tek renkli katman da aynı yolu kullanır', () {
    for (final name in ['ic_launcher_foreground', 'ic_launcher_monochrome']) {
      final xml = File('android/app/src/main/res/drawable/$name.xml')
          .readAsStringSync();
      expect(xml, contains('android:pathData="${KeyKeyLogo.pathData}"'));
    }
  });

  test('simgede K, 66 dp güvenli dairenin içinde', () {
    final transform = RegExp(
      r'translate\(([\d.]+) ([\d.]+)\) scale\(([\d.]+)\)',
    ).firstMatch(svg)!;
    final tx = double.parse(transform.group(1)!);
    final ty = double.parse(transform.group(2)!);
    final s = double.parse(transform.group(3)!);
    final bounds = KeyKeyLogo.parsePath(KeyKeyLogo.pathData).getBounds();
    for (final corner in [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ]) {
      final x = tx + corner.dx * s - 54;
      final y = ty + corner.dy * s - 54;
      expect(sqrt(x * x + y * y), lessThanOrEqualTo(33));
    }
  });

  test('uygulamadaki logoda K beyaz dairenin içinde', () {
    final bounds = KeyKeyLogo.logoPath().getBounds();
    for (final corner in [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ]) {
      final x = corner.dx - 50;
      final y = corner.dy - 50;
      expect(sqrt(x * x + y * y), lessThan(50));
    }
  });
}
