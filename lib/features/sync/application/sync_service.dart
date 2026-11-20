import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_merger.dart';
import 'package:sodium/sodium_sumo.dart';

/// Klasördeki bir telefon.
final class SyncDevice {
  const new({
    required this.device,
    this.name,
    this.modified,
    this.self = false,
  });

  final String device;

  /// Telefonun modeli; dosyası hiç açılmadıysa `null`.
  final String? name;
  final DateTime? modified;

  /// Bu telefon mu.
  final bool self;
}

/// Bir eşitlemenin sonucu.
final class SyncResult {
  const new({
    required this.at,
    required this.digest,
    this.issues = const [],
    this.devices = const [],
    this.uploaded = false,
    this.changedLocal = false,
  });

  final DateTime at;

  /// Birleşmiş halin özeti; ayar kaydına `lastDigest` olarak yazılır.
  final String digest;
  final List<SyncIssue> issues;
  final List<SyncDevice> devices;

  /// Bu telefonun dosyası yüklendi mi.
  final bool uploaded;

  /// Yerel kasa değişti mi.
  final bool changedLocal;
}

/// Klasörde başka bir kasanın dosyası var; eşitleme hiçbir şey yazmadı.
final class OtherVaultException implements Exception {
  const new();

  @override
  String toString() => 'OtherVaultException';
}

/// Senkron açılırken klasörün durumu.
sealed class FolderState {
  const new();
}

/// Senkron dosyası yok.
final class FolderEmpty extends FolderState {
  const new();
}

/// Dosyaların hepsi bu kasanın.
final class FolderSameVault extends FolderState {
  const new();
}

/// Dosyaların hepsi başka tek bir kasanın; [newest] en yeni dosyası (bu
/// telefonu o kasaya katmak için).
final class FolderOtherVault extends FolderState {
  const new(this.newest);

  final BackupFile newest;
}

/// Klasörde birden çok kasanın dosyası var.
final class FolderMixedVaults extends FolderState {
  const new();
}

/// Bir kasa oturumu boyunca bellekte tutulan bilgiler: değişmeyen dosya
/// yeniden indirilmez. Kasa kilitlenince atılır.
final class SyncCache {
  final _etags = <String, String>{};
  final _names = <String, String?>{};

  /// Bu telefonun yüklediği dosya; bir sonraki listede ETag'i öğrenilir.
  String? _uploaded;
}

/// Senkron klasörüyle bir eşitleme: indir, birleştir, kendi dosyanı yükle.
/// Tasarım: `resources/docs/senkron.md`. Kontrolcü testleri sahtesini
/// verebilsin diye `final` değil.
class SyncService {
  new({
    required this._store,
    required this._codec,
    required this._sodium,
    required this._transport,
    required this._device,
    required this._deviceName,
    required this._now,
  });

  static const _prefix = 'keykey-sync-';
  static const _suffix = '.keykey';
  static final _name = RegExp(r'^keykey-sync-([0-9a-f]{6})\.keykey$');
  static const _settingsType = 'settings';

  final VaultStore _store;
  final BackupCodec _codec;
  final SodiumSumo _sodium;
  final SyncTransport Function(SyncSettings settings) _transport;
  final String _device;
  final Future<String> Function() _deviceName;
  final DateTime Function() _now;

  String get _ownName => fileName(_device);

  /// Bir telefonun senkron dosyasının adı.
  static String fileName(String device) => '$_prefix$device$_suffix';

  /// Klasörü (yoksa oluşturup) okur ve dosyaların yalnızca şifresiz üst
  /// bilgisine bakar. Okunamayan dosyalar sayılmaz.
  ///
  /// [vaultId] `null` ise (kasası olmayan yeni telefon) tek kasalı bir klasör
  /// [FolderOtherVault] olarak, en yeni dosyasıyla döner.
  Future<FolderState> inspect(SyncSettings settings, Uint8List? vaultId) async {
    final transport = _transport(settings);
    await transport.ensureFolder();
    final files = [
      for (final file in await transport.list())
        if (_name.hasMatch(file.name)) file,
    ];
    final ours = <BackupFile>[];
    final others = <(RemoteFile, BackupFile)>[];
    for (final remote in files) {
      final BackupFile file;
      try {
        file = _codec.parse(await transport.read(remote.name));
      } on InvalidBackupException {
        continue;
      }
      if (vaultId != null && _sameBytes(file.header.vaultId, vaultId)) {
        ours.add(file);
      } else {
        others.add((remote, file));
      }
    }
    if (others.isEmpty) {
      return ours.isEmpty ? const FolderEmpty() : const FolderSameVault();
    }
    final otherIds = {
      for (final (_, f) in others) base64.encode(f.header.vaultId),
    };
    if (ours.isNotEmpty || otherIds.length > 1) {
      return const FolderMixedVaults();
    }
    others.sort((a, b) {
      final at = a.$1.modified;
      final bt = b.$1.modified;
      if (at != null && bt != null && at != bt) return at.compareTo(bt);
      if (at != bt) return at == null ? -1 : 1;
      return a.$1.name.compareTo(b.$1.name);
    });
    return FolderOtherVault(others.last.$2);
  }

  /// Bir eşitleme. Okuma ya da açma sırasında hata olursa kasa değişmez;
  /// klasörde başka kasanın dosyası varsa [OtherVaultException]. Birleşme
  /// yazıldıktan sonra yükleme hata verirse kasa birleşmiş kalır; sonuç
  /// dönmediği için son özet de değişmez ve sonraki eşitleme yeniden yükler.
  Future<SyncResult> sync(
    VaultSession session,
    SyncSettings settings, {
    SyncCache? cache,
  }) async {
    final memory = cache ?? SyncCache();
    final transport = _transport(settings);
    final listed = [
      for (final file in await transport.list())
        if (_name.hasMatch(file.name)) file,
    ]..sort((a, b) => a.name.compareTo(b.name));

    // İndirme: değişmeyen dosya ve bu telefonun az önce yüklediği atlanır.
    final issues = <SyncIssue>[];
    final downloaded = <(RemoteFile, BackupFile)>[];
    for (final remote in listed) {
      if (remote.name == memory._uploaded && remote.etag != null) {
        memory._etags[remote.name] = remote.etag!;
        memory._uploaded = null;
        continue;
      }
      final etag = remote.etag;
      if (etag != null && memory._etags[remote.name] == etag) continue;
      final device = _deviceOf(remote.name);
      final bytes = await transport.read(remote.name);
      try {
        downloaded.add((remote, _codec.parse(bytes)));
      } on NewerBackupException {
        issues.add(NewerApp(device));
      } on InvalidBackupException {
        issues.add(UnreadableDevice(device));
      }
    }
    final vaultId = session.header.vaultId;
    if (downloaded.any((d) => !_sameBytes(d.$2.header.vaultId, vaultId))) {
      throw const OtherVaultException();
    }

    final sources = <SyncSource>[];
    for (final (remote, file) in downloaded) {
      final device = _deviceOf(remote.name);
      final BackupContents contents;
      try {
        contents = await _codec.open(file, session.vaultKey);
      } on NewerBackupException {
        issues.add(NewerApp(device));
        continue;
      } on InvalidBackupException {
        issues.add(UnreadableDevice(device));
        continue;
      } on CryptoException {
        issues.add(UnreadableDevice(device));
        continue;
      }
      final info = contents.sync;
      if (info == null || info.device != device) {
        issues.add(UnreadableDevice(device));
        continue;
      }
      sources.add(
        SyncSource(
          device: device,
          deviceName: info.deviceName,
          header: file.header,
          contents: contents,
          modified: remote.modified,
        ),
      );
    }

    final local = await _localState(session);
    final plan = SyncMerger(
      cipher: session.records,
      now: _now(),
    ).merge(local, sources);
    if (!plan.isEmpty) {
      await _store.applyChanges(plan.changes);
      final header = plan.changes.header;
      if (header != null) session.header = header;
    }
    issues.addAll(plan.issues);

    // Sorunsuz dosyalar bir dahaki eşitlemede indirilmez.
    final troubled = {for (final issue in issues) ?_issueDevice(issue)};
    for (final source in sources) {
      final name = fileName(source.device);
      memory._names[name] = source.deviceName;
      final etag = listed.firstWhere((f) => f.name == name).etag;
      if (etag != null && !troubled.contains(source.device)) {
        memory._etags[name] = etag;
      } else {
        memory._etags.remove(name);
      }
    }

    final state = plan.isEmpty ? local : await _localState(session);
    final digest = _digest(state);
    final ownListed = listed.any((f) => f.name == _ownName);
    var uploaded = false;
    final deviceName = await _deviceName();
    if (digest != settings.lastDigest || !ownListed) {
      final bytes = await _codec.encode(
        header: state.header,
        vaultKey: session.vaultKey,
        records: state.records,
        createdAt: _now(),
        sync: SyncInfo(
          device: _device,
          deviceName: deviceName.isEmpty ? null : _clip(deviceName),
          passwordChangedAt: state.times.passwordChangedAt,
          recoveryChangedAt: state.times.recoveryChangedAt,
          deleted: state.tombstones,
        ),
      );
      await transport.write(_ownName, bytes);
      memory
        .._uploaded = _ownName
        .._etags.remove(_ownName);
      uploaded = true;
    }

    final at = _now();
    return SyncResult(
      at: at,
      digest: digest,
      issues: issues,
      changedLocal: !plan.isEmpty,
      uploaded: uploaded,
      devices: [
        for (final remote in listed)
          if (remote.name != _ownName)
            SyncDevice(
              device: _deviceOf(remote.name),
              name: memory._names[remote.name],
              modified: remote.modified,
            ),
        SyncDevice(
          device: _device,
          name: deviceName,
          modified: uploaded
              ? at
              : listed.where((f) => f.name == _ownName).firstOrNull?.modified,
          self: true,
        ),
      ],
    );
  }

  /// Bir telefonun dosyasını klasörden siler.
  Future<void> removeDevice(SyncSettings settings, String device) async {
    if (!SyncInfo.devicePattern.hasMatch(device)) {
      throw ArgumentError.value(device, 'device', 'Geçersiz cihaz kimliği');
    }
    await _transport(settings).delete(fileName(device));
  }

  Future<LocalState> _localState(VaultSession session) async => LocalState(
    records: [
      for (final record in await _store.allRecords())
        if (record.type != _settingsType) record,
    ],
    tombstones: await _store.allTombstones(),
    header: session.header,
    times: await _store.readHeaderTimes(),
  );

  /// Birleşmiş halin özeti (BLAKE2b-256, onaltılık): kayıtların kimliği,
  /// türü, `updatedAt` değeri ve şifreli verisinin özeti; silme kayıtları;
  /// üst bilgi; yuva zamanları. Hepsi sıralı ve uzunluk önekli.
  String _digest(LocalState state) {
    final out = BytesBuilder(copy: false);
    void bytes(List<int> value) {
      out
        ..add(_int(value.length))
        ..add(value);
    }

    final records = [...state.records]
      ..sort((a, b) => _compareBytes(a.id, b.id));
    out.add(_int(records.length));
    for (final record in records) {
      bytes(record.id);
      bytes(utf8.encode(record.type));
      out.add(_int(record.updatedAt.millisecondsSinceEpoch));
      bytes(_hash(record.blob));
    }
    final tombstones = [...state.tombstones]
      ..sort((a, b) => _compareBytes(a.id, b.id));
    out.add(_int(tombstones.length));
    for (final tombstone in tombstones) {
      bytes(tombstone.id);
      out.add(_int(tombstone.deletedAt.millisecondsSinceEpoch));
    }
    bytes(utf8.encode(state.header.toJsonString()));
    out
      ..add(_int(state.times.passwordChangedAt?.millisecondsSinceEpoch ?? -1))
      ..add(_int(state.times.recoveryChangedAt?.millisecondsSinceEpoch ?? -1));
    final digest = _hash(out.takeBytes());
    return [for (final byte in digest) byte.toRadixString(16).padLeft(2, '0')]
        .join();
  }

  Uint8List _hash(Uint8List message) =>
      _sodium.crypto.genericHash(message: message, outLen: 32);

  static Uint8List _int(int value) =>
      (ByteData(8)..setInt64(0, value)).buffer.asUint8List();

  static String _deviceOf(String name) => _name.firstMatch(name)!.group(1)!;

  static String? _issueDevice(SyncIssue issue) => switch (issue) {
    ClockAhead(:final device) ||
    UnreadableDevice(:final device) ||
    TypeConflict(:final device) ||
    NewerApp(:final device) ||
    SlotsDiffer(:final device) => device,
    PasswordAdopted() || RecoveryAdopted() => null,
  };

  static String _clip(String name) => name.length > SyncInfo.maxDeviceNameLength
      ? name.substring(0, SyncInfo.maxDeviceNameLength)
      : name;

  static bool _sameBytes(Uint8List a, Uint8List b) => _compareBytes(a, b) == 0;

  static int _compareBytes(Uint8List a, Uint8List b) {
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }
}
