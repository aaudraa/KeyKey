/// Yanlış parola beklemesini dakika:saniye olarak yazar (`15:00`, `1:30`).
String formatWait(Duration wait) {
  final minutes = wait.inMinutes;
  final seconds = wait.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
