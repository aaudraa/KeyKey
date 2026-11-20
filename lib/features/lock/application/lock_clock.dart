import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Arka plan kilidinin iki saati.
///
/// Duvar saati telefon uyurken de ilerler ama kullanıcı geri alabilir.
/// Tekdüze saat Android'de telefonun açılışından beri geçen süredir
/// (`CLOCK_BOOTTIME`): uykuda da ilerler ve ayarlanamaz. Süre ikisinden
/// biriyle dolmuşsa dolmuş sayılır (güvenlik tasarımı, "Otomatik kilit").
abstract interface class LockClock {
  DateTime now();

  /// Tekdüze süre: Android'de telefonun açılışından, başka yerde (testler)
  /// saatin kurulmasından beri.
  Duration elapsed();
}

final class SystemLockClock implements LockClock {
  /// Dart'ın `Stopwatch`'ı `CLOCK_MONOTONIC` kullanır ve telefon uyurken
  /// durur; uyku ile saati geri almak bir araya gelince süre uzardı. Bu
  /// yüzden Android'de doğrudan `CLOCK_BOOTTIME` okunur.
  final _BootTime? _boot = Platform.isAndroid ? _BootTime.open() : null;
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  DateTime now() => DateTime.now();

  @override
  Duration elapsed() => _boot?.elapsed() ?? _stopwatch.elapsed;
}

final class _Timespec extends Struct {
  @Long()
  external int seconds;

  @Long()
  external int nanoseconds;
}

typedef _ClockGettimeNative = Int32 Function(Int32, Pointer<_Timespec>);
typedef _ClockGettime = int Function(int, Pointer<_Timespec>);
typedef _MallocNative = Pointer<Void> Function(IntPtr);
typedef _Malloc = Pointer<Void> Function(int);

/// libc'nin `clock_gettime(CLOCK_BOOTTIME)` çağrısı. Sonucun yazıldığı alan
/// saatle birlikte bir kez ayrılır; saat uygulama boyunca yaşar.
final class _BootTime {
  factory open() {
    final libc = DynamicLibrary.open('libc.so');
    final malloc = libc.lookupFunction<_MallocNative, _Malloc>('malloc');
    final buffer = malloc(sizeOf<_Timespec>()).cast<_Timespec>();
    if (buffer == nullptr) throw StateError('Bellek ayrılamadı.');
    return _BootTime._(
      libc.lookupFunction<_ClockGettimeNative, _ClockGettime>(
        'clock_gettime',
        isLeaf: true,
      ),
      buffer,
    );
  }

  new _(this._clockGettime, this._buffer);

  /// Linux'ta `CLOCK_BOOTTIME`.
  static const _clockBoottime = 7;

  final _ClockGettime _clockGettime;
  final Pointer<_Timespec> _buffer;

  Duration elapsed() {
    if (_clockGettime(_clockBoottime, _buffer) != 0) {
      throw StateError('CLOCK_BOOTTIME okunamadı.');
    }
    final time = _buffer.ref;
    return Duration(
      microseconds:
          time.seconds * Duration.microsecondsPerSecond +
          time.nanoseconds ~/ 1000,
    );
  }
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
