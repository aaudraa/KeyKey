import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/features/lock/application/lock_clock.dart';

/// Arka plan kilidinin tekdüze saati telefon uyurken de saymalı ve
/// ayarlanamamalı: Android'de açılıştan beri geçen süre (CLOCK_BOOTTIME).
/// Dart'ın `Stopwatch`'ı uykuda durur; uyku ile saati geri almak bir araya
/// gelince bekleme süresi uzardı (güvenlik tasarımı, "Otomatik kilit").
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('tekdüze saat telefonun açılışından beri sayıyor', () {
    final elapsed = SystemLockClock().elapsed();

    // Uygulama yeni açıldı, telefon çok önce açılmıştı. Stopwatch sıfırdan
    // başlardı.
    expect(elapsed, greaterThan(const Duration(seconds: 30)));
    final String uptime;
    try {
      uptime = File('/proc/uptime').readAsStringSync();
    } on FileSystemException {
      return; // Bazı sürümler /proc/uptime'ı uygulamalara göstermez.
    }
    // /proc/uptime'ın ilk değeri de CLOCK_BOOTTIME.
    final seconds = double.parse(uptime.split(' ').first);
    expect((elapsed.inMilliseconds / 1000 - seconds).abs(), lessThan(2));
  });

  test('tekdüze saat ilerliyor', () async {
    final clock = SystemLockClock();
    final before = clock.elapsed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final after = clock.elapsed() - before;
    expect(after, greaterThanOrEqualTo(const Duration(milliseconds: 250)));
    expect(after, lessThan(const Duration(seconds: 5)));
  });
}
