import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';
import 'package:keykey/features/backup/application/backup_service.dart';

/// Klasör seçmenin sonucu.
sealed class FolderPick {
  const new();
}

/// Klasör seçildi; KeyKey'in bu klasör için kalıcı izni var.
final class FolderPicked extends FolderPick {
  const new({required this.uri, required this.name});

  /// Klasör ağacının adresi (`content://…/tree/…`).
  final String uri;

  /// Ayarlarda gösterilen ad.
  final String name;
}

final class FolderPickCancelled extends FolderPick {
  const new();
}

final class FolderPickFailed extends FolderPick {
  const new();
}

/// Otomatik yedeğin klasörü: Android'in klasör seçicisi ve seçilen klasöre
/// yazma, listeleme, silme.
///
/// Seçici ayrı bir etkinlik açar; çağıran, kasanın arka planda kilitlenmemesi
/// için [pick]'i `ExternalActivityGate` içinde yürütmelidir. Diğer işlemler
/// etkinlik açmaz.
abstract interface class BackupFolders {
  Future<FolderPick> pick();

  /// Bu cihazda [uri] için kalıcı okuma ve yazma izni var mı.
  Future<bool> hasAccess(String uri);

  /// Klasördeki dosyaların adları; klasöre erişilemiyorsa `null`.
  Future<List<String>?> list(String uri);

  /// [bytes]'ı [name] adlı yeni dosyaya yazar ve geri okuyup doğrular.
  /// [bytes] işi bitince sıfırlanır.
  Future<bool> write(String uri, String name, Uint8List bytes);

  /// Adı [names] içinde olan dosyaları siler; silineni sayar.
  Future<int> delete(String uri, List<String> names);

  /// [uri] için alınan kalıcı izni bırakır.
  Future<void> release(String uri);
}

final class PigeonBackupFolders implements BackupFolders {
  new([BackupFolderApi? api]) : _api = api ?? BackupFolderApi();

  final BackupFolderApi _api;

  @override
  Future<FolderPick> pick() async {
    final result = await _api.pick();
    final uri = result.uri;
    return switch (result.status) {
      FolderPickStatus.done when uri != null => FolderPicked(
        uri: uri,
        name: result.name ?? uri,
      ),
      FolderPickStatus.cancelled => const FolderPickCancelled(),
      _ => const FolderPickFailed(),
    };
  }

  @override
  Future<bool> hasAccess(String uri) => _api.hasAccess(uri);

  @override
  Future<List<String>?> list(String uri) => _api.list(uri);

  @override
  Future<bool> write(String uri, String name, Uint8List bytes) async {
    try {
      return await _api.write(uri, name, BackupService.mimeType, bytes);
    } on PlatformException {
      return false;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  @override
  Future<int> delete(String uri, List<String> names) => _api.delete(uri, names);

  @override
  Future<void> release(String uri) => _api.release(uri);
}

/// `main` doldurur, testler kendi sahtesini verir.
final backupFoldersProvider = Provider<BackupFolders>(
  (ref) => throw UnimplementedError('Klasör köprüsü sağlanmadı.'),
);
