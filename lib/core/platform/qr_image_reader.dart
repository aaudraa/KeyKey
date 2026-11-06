import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

/// Görselden QR okumanın sonucu.
sealed class QrImageResult {
  const new();
}

/// Kullanıcı görsel seçmedi.
final class QrImageCancelled extends QrImageResult {
  const new();
}

/// Görselde okunabilen QR yok veya görsel açılamadı.
final class QrImageNotFound extends QrImageResult {
  const new();
}

final class QrImageRead extends QrImageResult {
  const new(this.text);

  final String text;
}

/// Kullanıcının seçtiği görseldeki QR kodunu okur.
abstract interface class QrImageReader {
  Future<QrImageResult> pickAndRead();
}

/// Android'in fotoğraf seçicisini kullanır, depolama izni gerekmez.
///
/// `image_picker` seçilen görseli uygulamanın önbelleğine kopyalar. Görselde
/// gizli anahtar olduğu için kopya okunur okunmaz silinir.
final class ZxingQrImageReader implements QrImageReader {
  new([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Görsel bu boyuta küçültülerek okunur. Varsayılan 768, çok hesaplı
  /// Google Authenticator QR'larında yetmeyebiliyor.
  static const _maxSize = 2048;

  @override
  Future<QrImageResult> pickAndRead() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return const QrImageCancelled();
    return await readFile(file);
  }

  /// [file]'daki QR'ı okur ve dosyayı siler.
  Future<QrImageResult> readFile(XFile file) async {
    try {
      final code = await zx.readBarcodeImagePath(
        file,
        DecodeParams(
          format: Format.qrCode,
          tryHarder: true,
          tryInverted: true,
          maxSize: _maxSize,
        ),
      );
      final text = code.text;
      return code.isValid && text != null
          ? QrImageRead(text)
          : const QrImageNotFound();
    } finally {
      await _delete(file.path);
    }
  }

  static Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Zaten yoksa sorun değil.
    }
  }
}

/// `main` doldurur, testler kendi okuyucusunu verir.
final qrImageReaderProvider = Provider<QrImageReader>(
  (ref) => throw UnimplementedError('Görsel okuyucu sağlanmadı.'),
);
