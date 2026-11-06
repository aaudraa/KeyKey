import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/vault/application/login_search.dart';

/// Çöp kutusunda olmayan ve [query]'ye uyan hesaplar: önce favoriler, sonra
/// servis ve hesap adına göre.
///
/// Arama, parola listesindeki gibi sözcük sözcük ve yalnızca servis ve hesap
/// adında yapılır. Türkçe harfler sadeleştirilir.
List<OtpItem> visibleOtps(Iterable<OtpItem> items, String query) {
  final words = foldForSearch(query)
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  final matches = <({OtpItem item, String key})>[];
  for (final item in items) {
    final content = item.content;
    if (content.isTrashed) continue;
    final text = foldForSearch('${content.issuer}\n${content.account}');
    if (words.every(text.contains)) {
      matches.add((item: item, key: _sortKey(content)));
    }
  }
  matches.sort((a, b) => a.key.compareTo(b.key));
  return [for (final match in matches) match.item];
}

String _sortKey(OtpContent content) =>
    '${content.favorite ? 0 : 1}'
    '${foldForSearch(content.issuer)}\u0000${foldForSearch(content.account)}';
