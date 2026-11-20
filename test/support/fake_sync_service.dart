import 'dart:async';
import 'dart:typed_data';

import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_merger.dart';
import 'package:keykey/features/sync/application/sync_service.dart';

/// Ağa çıkmayan eşitleme: çağrıları sayar, istenirse kapıda bekler.
final class FakeSyncService implements SyncService {
  int calls = 0;
  final caches = <SyncCache?>[];
  Completer<void>? gate;
  Exception? error;
  List<SyncIssue> issues = const [];
  bool changedLocal = false;
  DateTime at = DateTime.utc(2026, 11, 20, 12);

  static final String digest = 'ab' * 32;

  @override
  Future<SyncResult> sync(
    VaultSession session,
    SyncSettings settings, {
    SyncCache? cache,
  }) async {
    calls++;
    caches.add(cache);
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return SyncResult(
      at: at,
      digest: digest,
      issues: issues,
      changedLocal: changedLocal,
      uploaded: true,
      devices: const [SyncDevice(device: 'a1b2c3', self: true)],
    );
  }

  @override
  Future<FolderState> inspect(SyncSettings settings, Uint8List vaultId) =>
      throw UnimplementedError();

  @override
  Future<void> removeDevice(SyncSettings settings, String device) =>
      throw UnimplementedError();
}
