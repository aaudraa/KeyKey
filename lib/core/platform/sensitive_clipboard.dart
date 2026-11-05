import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';

/// Parola gibi hassas metinleri panoya kopyalar.
///
/// Pano [clearAfter] sonra temizlenir, uygulama arka plandayken de. Kurallar
/// ve sınırlar güvenlik tasarımı belgesinin Pano bölümündedir.
abstract interface class SensitiveClipboard {
  static const clearAfter = Duration(seconds: 30);

  Future<void> copy(String text);
}

final class PigeonSensitiveClipboard implements SensitiveClipboard {
  new([ClipboardApi? api]) : _api = api ?? ClipboardApi();

  final ClipboardApi _api;

  @override
  Future<void> copy(String text) =>
      _api.copySensitive(text, SensitiveClipboard.clearAfter.inMilliseconds);
}

/// `main` doldurur, testler kendi panosunu verir.
final sensitiveClipboardProvider = Provider<SensitiveClipboard>(
  (ref) => throw UnimplementedError('Pano sağlanmadı.'),
);
