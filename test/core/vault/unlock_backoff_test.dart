import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/vault/unlock_backoff.dart';

void main() {
  final now = DateTime.utc(2026, 11, 5, 12);

  group('bekleme tablosu', () {
    test('tasarım belgesindeki tabloyla aynı', () {
      const expected = {
        0: Duration.zero,
        1: Duration.zero,
        2: Duration.zero,
        3: Duration.zero,
        4: Duration(seconds: 5),
        5: Duration(seconds: 15),
        6: Duration(seconds: 30),
        7: Duration(minutes: 1),
        8: Duration(minutes: 5),
        9: Duration(minutes: 15),
        50: Duration(minutes: 15),
      };
      expected.forEach((attempts, wait) {
        expect(UnlockBackoff.waitAfter(attempts), wait, reason: '$attempts');
      });
    });
  });

  group('kalan süre', () {
    test('hiç hata yoksa sıfır', () {
      expect(
        UnlockBackoff.remaining(
          failedAttempts: 0,
          lastFailedAt: null,
          now: now,
        ),
        Duration.zero,
      );
    });

    test('süre geçtikçe azalıyor', () {
      final lastFailedAt = now.subtract(const Duration(seconds: 2));
      expect(
        UnlockBackoff.remaining(
          failedAttempts: 4,
          lastFailedAt: lastFailedAt,
          now: now,
        ),
        const Duration(seconds: 3),
      );
    });

    test('süre dolunca sıfır, eksiye düşmüyor', () {
      final lastFailedAt = now.subtract(const Duration(hours: 1));
      expect(
        UnlockBackoff.remaining(
          failedAttempts: 9,
          lastFailedAt: lastFailedAt,
          now: now,
        ),
        Duration.zero,
      );
    });

    test('saat geri alınırsa bekleme baştan başlıyor', () {
      final lastFailedAt = now.add(const Duration(days: 1));
      expect(
        UnlockBackoff.remaining(
          failedAttempts: 8,
          lastFailedAt: lastFailedAt,
          now: now,
        ),
        const Duration(minutes: 5),
      );
    });
  });
}
