import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dosya seçmenin sonucu.
sealed class ExportFileResult {
  const new();
}

final class ExportFileCancelled extends ExportFileResult {
  const new();
}

/// Dosya okunamayacak kadar büyük.
final class ExportFileTooLarge extends ExportFileResult {
  const new();
}

final class ExportFileRead extends ExportFileResult {
  const new(this.bytes);

  final Uint8List bytes;
}

/// Başka bir uygulamanın dışa aktarma dosyasını seçtirir ve okur.
abstract interface class ExportFilePicker {
  Future<ExportFileResult> pickAndRead();
}

/// Android'in belge seçicisini kullanır, depolama izni gerekmez.
///
/// `file_selector` seçilen dosyayı uygulamanın önbelleğine kopyalar. Dosyada
/// gizli anahtarlar olduğu için kopya okunur okunmaz silinir.
final class FileSelectorExportPicker implements ExportFilePicker {
  /// Dışa aktarma dosyaları birkaç KB'tır. Daha büyüğü belleğe alınmaz.
  static const int maxSize = 10 * 1024 * 1024;

  @override
  Future<ExportFileResult> pickAndRead() async {
    final file = await openFile();
    if (file == null) return const ExportFileCancelled();
    try {
      if (await file.length() > maxSize) return const ExportFileTooLarge();
      // Android'da gelen dizi değiştirilemez; okuyan taraf işi bitince
      // sıfırlayabilsin diye kopyalanır.
      return ExportFileRead(Uint8List.fromList(await file.readAsBytes()));
    } finally {
      await _delete(file.path);
    }
  }

  static Future<void> _delete(String path) async {
    if (path.isEmpty) return;
    final copy = File(path);
    try {
      await copy.delete();
      // file_selector her kopya için ayrı bir klasör açıyor, boşsa o da gitsin.
      await copy.parent.delete();
    } on FileSystemException {
      // Zaten yoksa veya klasör boş değilse sorun değil.
    }
  }
}

/// `main` doldurur, testler kendi seçicisini verir.
final exportFilePickerProvider = Provider<ExportFilePicker>(
  (ref) => throw UnimplementedError('Dosya seçici sağlanmadı.'),
);
