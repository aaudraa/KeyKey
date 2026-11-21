import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';

/// Belge kaydetmenin sonucu.
enum DocumentSaveResult {
  /// Yazıldı ve geri okunup doğrulandı.
  saved,

  /// Kullanıcı vazgeçti.
  cancelled,

  /// Yazılamadı veya yazılan geri okunamadı.
  failed,
}

/// Belge açmanın sonucu.
sealed class DocumentOpenResult {
  const new();
}

final class DocumentOpened extends DocumentOpenResult {
  const new(this.bytes);

  /// Değiştirilebilir; okuyan işi bitince sıfırlayabilir.
  final Uint8List bytes;
}

final class DocumentOpenCancelled extends DocumentOpenResult {
  const new();
}

final class DocumentTooLarge extends DocumentOpenResult {
  const new();
}

final class DocumentOpenFailed extends DocumentOpenResult {
  const new();
}

/// Android'in belge oluşturma ve açma ekranları.
///
/// İkisi de ayrı bir etkinlik açar; çağıran, kasanın arka planda
/// kilitlenmemesi için işlemi `ExternalActivityGate` içinde yürütmelidir.
abstract interface class DocumentFiles {
  /// [bytes] işi bitince sıfırlanır.
  Future<DocumentSaveResult> save({
    required String suggestedName,
    required String mimeType,
    required Uint8List bytes,
  });

  Future<DocumentOpenResult> open({
    required List<String> mimeTypes,
    required int maxBytes,
  });
}

final class PigeonDocumentFiles implements DocumentFiles {
  new([DocumentApi? api]) : _api = api ?? DocumentApi();

  final DocumentApi _api;

  @override
  Future<DocumentSaveResult> save({
    required String suggestedName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    try {
      final result = await _api.save(suggestedName, mimeType, bytes);
      return switch (result.status) {
        DocumentStatus.done => DocumentSaveResult.saved,
        DocumentStatus.cancelled => DocumentSaveResult.cancelled,
        DocumentStatus.tooLarge ||
        DocumentStatus.failed => DocumentSaveResult.failed,
      };
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  @override
  Future<DocumentOpenResult> open({
    required List<String> mimeTypes,
    required int maxBytes,
  }) async {
    final result = await _api.open(mimeTypes, maxBytes);
    final bytes = result.bytes;
    return switch (result.status) {
      DocumentStatus.done when bytes != null =>
        // Pigeon'un verdiği dizi değiştirilemez olabilir.
        DocumentOpened(Uint8List.fromList(bytes)),
      DocumentStatus.cancelled => const DocumentOpenCancelled(),
      DocumentStatus.tooLarge => const DocumentTooLarge(),
      _ => const DocumentOpenFailed(),
    };
  }
}

/// `main` doldurur, testler kendi sahtesini verir.
final documentFilesProvider = Provider<DocumentFiles>(
  (ref) => throw UnimplementedError('Belge köprüsü sağlanmadı.'),
);
