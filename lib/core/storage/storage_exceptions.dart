/// Depolama katmanının temiz hataları.
sealed class StorageException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}

/// Veritabanı dosyası bu sürümün tanımadığı bir şemada.
final class UnsupportedSchemaException extends StorageException {
  new({required this.from, required this.to})
    : super('Şema sürümü $from, desteklenen sürüm $to.');

  final int from;
  final int to;
}

/// Kurulu bir kasanın üzerine yeni kasa yazılmak istendi.
final class VaultAlreadyExistsException extends StorageException {
  const new() : super('Kasa zaten kurulu.');
}

/// Henüz kurulmamış bir kasa güncellenmek istendi.
final class VaultNotFoundException extends StorageException {
  const new() : super('Kasa kurulu değil.');
}
