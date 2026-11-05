import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/core/platform/platform_api.g.dart';
import 'package:path_provider/path_provider.dart';

/// Güvenli panoyu gerçek Android'de sınar. Süreler testi kısaltmak için
/// uygulamadakinden (30 saniye) kısadır.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Arka plan testi uygulamayı arka plana alacak bir betik ister:
  // resources/scripts/clipboard-device-test.sh
  const driven = bool.fromEnvironment('KK_CLIPBOARD');

  final api = ClipboardApi();

  Future<String?> read() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  testWidgets('kopyalanan değer süre dolunca siliniyor', (tester) async {
    await api.copySensitive('kk-deneme-on', 2000);
    expect(await read(), 'kk-deneme-on');

    await Future<void>.delayed(const Duration(seconds: 4));

    expect(await read(), anyOf(isNull, isEmpty));
  });

  testWidgets('yeni kopya öncekinin süresini sıfırlıyor', (tester) async {
    // Uygulamadaki bütün kopyalamalar bu yoldan geçer. İlk kopyanın 2 saniyelik
    // temizliği iptal olmalı, ikinci kopya 8 saniye panoda kalmalı.
    await api.copySensitive('kk-deneme-ilk', 2000);
    await api.copySensitive('kk-deneme-ikinci', 8000);

    await Future<void>.delayed(const Duration(seconds: 4));
    expect(await read(), 'kk-deneme-ikinci');

    await Future<void>.delayed(const Duration(seconds: 6));
    expect(await read(), anyOf(isNull, isEmpty));
  });

  testWidgets('uygulama arka plandayken de siliniyor', (tester) async {
    final support = await getApplicationSupportDirectory();
    final signal = File('${support.path}/kk_pano_dondu');
    if (signal.existsSync()) signal.deleteSync();

    await api.copySensitive('kk-deneme-arka', 5000);
    expect(await read(), 'kk-deneme-arka');

    // Betik bunu görünce uygulamayı arka plana alır, 15 saniye sonra geri
    // getirir ve işaret dosyasını oluşturur.
    // ignore: avoid_print
    print('KKPANO_ARKA');
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!signal.existsSync()) {
      if (DateTime.now().isAfter(deadline)) fail('Uygulama geri gelmedi');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // Pano yalnızca odaktaki uygulamaya okunur, pencerenin odaklanmasını bekle.
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(await read(), anyOf(isNull, isEmpty));
  }, skip: !driven);
}
