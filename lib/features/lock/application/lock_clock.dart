import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Arka plan kilidinin iki saati.
///
/// Duvar saati telefon uyurken de ilerler ama kullanıcı geri alabilir;
/// tekdüze saat geri alınamaz ama telefon uyurken durabilir. Süre ikisinden
/// biriyle dolmuşsa dolmuş sayılır (güvenlik tasarımı, "Otomatik kilit").
abstract interface class LockClock {
  DateTime now();

  /// Uygulama açıldığından beri geçen tekdüze süre.
  Duration elapsed();
}

final class SystemLockClock implements LockClock {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  DateTime now() => DateTime.now();

  @override
  Duration elapsed() => _stopwatch.elapsed;
}

final lockClockProvider = Provider<LockClock>((ref) => SystemLockClock());

/// İki saatte birden okunan an.
typedef LockInstant = ({DateTime wall, Duration monotonic});

extension LockClockReading on LockClock {
  LockInstant read() => (wall: now(), monotonic: elapsed());

  /// [since] anından beri [limit] geçti mi? Duvar saati geri gittiyse de
  /// geçmiş sayılır.
  bool hasPassed(LockInstant since, Duration limit) {
    final wall = now().difference(since.wall);
    final monotonic = elapsed() - since.monotonic;
    return wall.isNegative || wall >= limit || monotonic >= limit;
  }
}
