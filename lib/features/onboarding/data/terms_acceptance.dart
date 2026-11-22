import 'dart:io';

/// Kullanım koşullarının sürümü. Koşullar değişince artırılır; daha eski
/// sürümü kabul etmiş kullanıcıya yenisi bir kez gösterilir. Sürüm 3:
/// senkron (şifreli kopya kullanıcının seçtiği sunucuda). Sürüm 4: açarsa
/// otomatik doldurmada uygulamanın sitesinin internetten doğrulanması.
const currentTermsVersion = 4;

/// Dosyadaki metni kabul edilen sürüme çevirir. Boş ya da tanınmayan
/// içerik hiç kabul edilmemiş (0) sayılır.
int parseTermsVersion(String text) => int.tryParse(text.trim()) ?? 0;

/// Kabul edilen koşul sürümünü saklar.
abstract interface class TermsAcceptanceStore {
  Future<void> write(int version);
}

/// Kabul kasanın dışında, şifresiz bir dosyada durur: koşullar kasa
/// kurulmadan ve kilit açılmadan önce gösterilir. İçinde yalnızca sürüm
/// numarası vardır; gizli bir bilgi değildir.
final class FileTermsAcceptanceStore implements TermsAcceptanceStore {
  new(this._file);

  final File _file;

  /// Dosya yoksa ya da okunamıyorsa 0.
  Future<int> read() async {
    try {
      return parseTermsVersion(await _file.readAsString());
    } on FileSystemException {
      return 0;
    } on FormatException {
      return 0;
    }
  }

  /// Şimdiki koşullar kabul edilmiş mi; daha eski sürümün kabulü sayılmaz.
  Future<bool> accepted() async => await read() >= currentTermsVersion;

  @override
  Future<void> write(int version) =>
      _file.writeAsString('$version', flush: true);
}
