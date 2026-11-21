import 'dart:async';

/// Yanlış parola beklemesini dakika:saniye olarak yazar (`15:00`, `1:30`).
String formatWait(Duration wait) {
  final minutes = wait.inMinutes;
  final seconds = wait.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Yanlış parola beklemesinin saniyelik sayacı. Kilit ekranı ve ana parola
/// değiştirme ekranı kullanır; her saniye [onTick] kalan süreyle çağrılır.
class WaitCountdown {
  new(this.onTick);

  final void Function(Duration left) onTick;
  Timer? _timer;
  Duration _left = Duration.zero;

  Duration get left => _left;

  bool get running => _left > Duration.zero;

  /// [wait] kadar saymaya başlar; süren sayımı bırakır.
  void start(Duration wait) {
    _timer?.cancel();
    _left = wait.isNegative ? Duration.zero : wait;
    onTick(_left);
    if (_left == Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = _left - const Duration(seconds: 1);
      _left = next.isNegative ? Duration.zero : next;
      onTick(_left);
      if (_left == Duration.zero) timer.cancel();
    });
  }

  void dispose() => _timer?.cancel();
}
