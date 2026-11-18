import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/backup_folders.dart';
import 'package:keykey/core/platform/platform_api.g.dart';
import 'package:keykey/features/backup/application/backup_service.dart';

/// Kotlin tarafının yerine: son çağrıyı kaydeder, verilen sonucu döner.
class _FakeApi implements BackupFolderApi {
  FolderPickResult pickResult = FolderPickResult(
    status: FolderPickStatus.cancelled,
  );
  bool writeResult = true;
  bool throwOnWrite = false;

  String? writtenMime;
  Uint8List? bytesSeenByWrite;

  @override
  Future<FolderPickResult> pick() async => pickResult;

  @override
  Future<bool> write(
    String folderUri,
    String name,
    String mimeType,
    Uint8List bytes,
  ) async {
    writtenMime = mimeType;
    bytesSeenByWrite = Uint8List.fromList(bytes);
    if (throwOnWrite) throw PlatformException(code: 'io');
    return writeResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeApi api;
  late PigeonBackupFolders folders;

  setUp(() {
    api = _FakeApi();
    folders = PigeonBackupFolders(api);
  });

  group('pick', () {
    test('seçilen klasör adresi ve adıyla döner', () async {
      api.pickResult = FolderPickResult(
        status: FolderPickStatus.done,
        uri: 'content://x/tree/1',
        name: 'KeyKey',
      );
      final result = await folders.pick();
      expect(result, isA<FolderPicked>());
      result as FolderPicked;
      expect(result.uri, 'content://x/tree/1');
      expect(result.name, 'KeyKey');
    });

    test('adres yoksa başarısız sayılır', () async {
      api.pickResult = FolderPickResult(status: FolderPickStatus.done);
      expect(await folders.pick(), isA<FolderPickFailed>());
    });

    test('vazgeçilirse vazgeçildi döner', () async {
      expect(await folders.pick(), isA<FolderPickCancelled>());
    });

    test('Kotlin başarısız derse başarısız döner', () async {
      api.pickResult = FolderPickResult(status: FolderPickStatus.failed);
      expect(await folders.pick(), isA<FolderPickFailed>());
    });
  });

  group('write', () {
    test('yedeğin türüyle yazar ve baytları sıfırlar', () async {
      final bytes = Uint8List.fromList([7, 8, 9]);
      expect(
        await folders.write('content://x/tree/1', 'a.keykey', bytes),
        isTrue,
      );
      expect(api.writtenMime, BackupService.mimeType);
      expect(api.bytesSeenByWrite, [7, 8, 9]);
      expect(bytes, everyElement(0));
    });

    test('yazılamazsa false döner, baytlar yine sıfırlanır', () async {
      api.writeResult = false;
      final bytes = Uint8List.fromList([1, 2]);
      expect(
        await folders.write('content://x/tree/1', 'a.keykey', bytes),
        isFalse,
      );
      expect(bytes, everyElement(0));
    });

    test('köprü hata atarsa false döner, baytlar yine sıfırlanır', () async {
      api.throwOnWrite = true;
      final bytes = Uint8List.fromList([1, 2]);
      expect(
        await folders.write('content://x/tree/1', 'a.keykey', bytes),
        isFalse,
      );
      expect(bytes, everyElement(0));
    });
  });
}
