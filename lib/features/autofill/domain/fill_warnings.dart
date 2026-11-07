import 'package:flutter/foundation.dart' show listEquals;
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Doldurmadan önce kullanıcıya söylenmesi gerekenler. Kurallar güvenlik
/// tasarımı belgesinin "Şüpheli durumlar" bölümünde.
enum FillWarning {
  /// Kayıt bu uygulama veya siteyle eşleşmiyor; kullanıcı kendisi seçti.
  noMatch,

  /// Tarayıcı olmayan bir uygulama bir web sayfası gösteriyor.
  webView,

  /// Sayfa şifresiz bağlantıyla (`http`) açılmış.
  insecure,

  /// Kayda bağlı uygulamanın paket adı aynı, imzası farklı.
  signatureMismatch,
}

bool _contains(Iterable<LoginItem> items, LoginItem item) =>
    items.any((other) => listEquals(other.id, item.id));

/// [item] seçilince gösterilecek uyarılar; boşsa doğrudan doldurulur.
Set<FillWarning> fillWarnings({
  required AutofillTarget target,
  required LoginItem item,
  required LoginMatches matches,
}) {
  final warnings = <FillWarning>{};
  final matched = _contains([for (final m in matches.matches) m.item], item);
  if (_contains(matches.signatureMismatches, item)) {
    warnings.add(FillWarning.signatureMismatch);
  } else if (!matched) {
    warnings.add(FillWarning.noMatch);
  }
  if (!matched && target.showsWebPage) {
    warnings.add(FillWarning.webView);
  }
  if (target.isWeb && target.webScheme?.toLowerCase() == 'http') {
    warnings.add(FillWarning.insecure);
  }
  return warnings;
}

/// Uygulama bu kayda bağlanabilir mi. Yalnızca imzası okunabilen, tarayıcı
/// olmayan bir uygulama, eşleşmeyen bir kayda bağlanır. İmzası tutmayan
/// kayda bağlama önerilmez: sahte uygulamanın imzası kayda girerdi.
bool canBindApp({
  required AutofillTarget target,
  required Set<FillWarning> warnings,
}) =>
    !target.isWeb &&
    target.certsSha256.isNotEmpty &&
    warnings.contains(FillWarning.noMatch) &&
    !warnings.contains(FillWarning.signatureMismatch);
