import 'package:keykey/features/vault/data/login_repository.dart';

/// Listenin sıralaması.
enum LoginSort { name, recentlyUpdated }

/// Hangi kayıtların gösterileceği. Alanlar birlikte uygulanır.
final class LoginFilter {
  const new({
    this.query = '',
    this.favoritesOnly = false,
    this.folder,
    this.sort = LoginSort.name,
  });

  final String query;
  final bool favoritesOnly;

  /// `null` ise bütün klasörler.
  final String? folder;
  final LoginSort sort;

  LoginFilter copyWith({
    String? query,
    bool? favoritesOnly,
    String? folder,
    bool clearFolder = false,
    LoginSort? sort,
  }) {
    return LoginFilter(
      query: query ?? this.query,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      folder: clearFolder ? null : folder ?? this.folder,
      sort: sort ?? this.sort,
    );
  }
}

const Map<int, int> _foldedLetters = {
  0x0130: 0x69, // İ
  0x0131: 0x69, // ı
  0x015F: 0x73, // ş
  0x015E: 0x73, // Ş
  0x011F: 0x67, // ğ
  0x011E: 0x67, // Ğ
  0x00E7: 0x63, // ç
  0x00C7: 0x63, // Ç
  0x00F6: 0x6F, // ö
  0x00D6: 0x6F, // Ö
  0x00FC: 0x75, // ü
  0x00DC: 0x75, // Ü
};

/// Aramada karşılaştırılacak biçim.
///
/// Dart'ın küçük harf çevirisi Türkçe `I` ve `İ` için doğru çalışmıyor. Bu
/// yüzden Türkçe harfler sadeleştirilir: "sifre" yazınca "Şifre" de bulunur.
String foldForSearch(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    buffer.writeCharCode(_foldedLetters[rune] ?? rune);
  }
  return buffer.toString().toLowerCase();
}

/// Aramanın baktığı alanlar. Parola, not ve özel alanlara bakılmaz.
String _searchText(LoginItem item) {
  final content = item.content;
  return foldForSearch(
    [
      content.name,
      content.username,
      ...content.urls,
      if (content.folder != null) content.folder!,
    ].join('\n'),
  );
}

/// Arama için önceden hazırlanmış bir kayıt.
///
/// Her tuşta bütün metinleri yeniden işlememek için bir kez hesaplanır.
final class IndexedLogin {
  new(this.item) : searchText = _searchText(item);

  final LoginItem item;
  final String searchText;
}

/// Çöp kutusu dışındaki kayıtları süzer ve sıralar.
List<LoginItem> filterLogins(List<IndexedLogin> logins, LoginFilter filter) {
  final words = foldForSearch(filter.query)
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  final matches = <LoginItem>[];
  for (final login in logins) {
    final content = login.item.content;
    if (content.isTrashed) continue;
    if (filter.favoritesOnly && !content.favorite) continue;
    if (filter.folder != null && content.folder != filter.folder) continue;
    if (words.every(login.searchText.contains)) matches.add(login.item);
  }
  return sortLogins(matches, filter.sort);
}

List<LoginItem> sortLogins(List<LoginItem> items, LoginSort sort) {
  final sorted = [...items];
  switch (sort) {
    case LoginSort.name:
      final keys = {
        for (final item in sorted) item: foldForSearch(item.content.name),
      };
      sorted.sort((a, b) => keys[a]!.compareTo(keys[b]!));
    case LoginSort.recentlyUpdated:
      sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  return sorted;
}

/// Kayıtlarda kullanılan klasörler, sıralı.
List<String> foldersOf(Iterable<LoginItem> items) {
  return {
    for (final item in items)
      if (!item.content.isTrashed && item.content.folder != null)
        item.content.folder!,
  }.toList()..sort((a, b) => foldForSearch(a).compareTo(foldForSearch(b)));
}
