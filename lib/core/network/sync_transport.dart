import 'dart:typed_data';

/// Senkron klasöründeki bir dosya.
final class RemoteFile {
  const new({required this.name, this.etag, this.size, this.modified});

  /// Klasör içindeki adı (yüzde kodu çözülmüş).
  final String name;
  final String? etag;
  final int? size;
  final DateTime? modified;
}

/// Senkron klasörüne erişim. Birleştirme, dosya biçimi ve arayüz ağ bilmez;
/// gerçek taşıyıcı `WebDavClient`, testler bellekte bir sahtesini kullanır.
abstract interface class SyncTransport {
  /// Klasör yoksa oluşturur.
  Future<void> ensureFolder();

  /// Klasörün doğrudan içindeki `keykey-sync-*.keykey` dosyaları.
  Future<List<RemoteFile>> list();

  Future<Uint8List> read(String name);

  /// Öteki telefonlar yarım dosya görmeyecek biçimde yazar.
  Future<void> write(String name, Uint8List bytes);

  /// Dosyayı siler; zaten yoksa sorun değildir.
  Future<void> delete(String name);
}

/// Taşıyıcı hatasının türü; kullanıcıya gösterilen mesaj bundan seçilir.
enum SyncFailureKind {
  /// Sunucuya ulaşılamadı ya da zaman aşımı.
  offline,

  /// Kullanıcı adı ya da uygulama parolası yanlış, ya da izin yok.
  unauthorized,

  /// Sunucunun sertifikasına güvenilmedi.
  certificate,

  /// Sunucu başka bir adrese yönlendirdi; yönlendirme izlenmez.
  redirect,

  /// Klasör ya da dosya yok.
  notFound,

  /// Sunucu hatası.
  server,

  /// Sunucuda yer kalmadı.
  insufficientStorage,

  /// Yanıt ya da dosya sınırdan büyük.
  tooLarge,

  /// Yanıt anlaşılmadı ya da geri okunan dosya yazılanla aynı değil.
  badResponse,
}

/// Taşıyıcı hatası. Mesaj adres yolunu, kullanıcı adını ve parolayı taşımaz.
final class SyncTransportException implements Exception {
  const new(this.kind);

  final SyncFailureKind kind;

  @override
  String toString() => 'SyncTransportException(${kind.name})';
}
