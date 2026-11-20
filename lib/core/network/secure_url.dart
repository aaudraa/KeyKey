/// Bu telefonun kendi adresleri. Bunlarda şifresiz bağlantıya izin verilir:
/// trafik telefondan çıkmaz (testler ve telefonda çalışan bir sunucu).
const loopbackHosts = {'127.0.0.1', 'localhost', '::1'};

/// Kullanıcının girdiği bir sunucu adresi ağ istemcilerince kabul edilir mi.
///
/// `https` ve bir sunucu adı gerekir; `http` yalnızca [loopbackHosts] için.
/// Adreste kullanıcı bilgisi (`ad:parola@`), sorgu ve parça olamaz: kimlik
/// bilgisi adreste taşınmaz, adres her istekte olduğu gibi kullanılır.
///
/// Flutter, Android'in şifresiz trafik yasağını Dart'ın `HttpClient`'ına
/// uygulamıyor; bu kural o yüzden Dart tarafında.
bool isSecureServiceUrl(Uri uri) {
  if (uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  return switch (uri.scheme) {
    'https' => true,
    'http' => loopbackHosts.contains(uri.host),
    _ => false,
  };
}
