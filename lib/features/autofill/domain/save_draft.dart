import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/domain_name.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Kaydedilecek yeni kaydın kendiliğinden bağlanacağı yer.
///
/// Güvenilen tarayıcıda sitenin adresi, başka bir uygulamada uygulamanın
/// kendisi (paket adı ve imza) bağlanır. WebView'ın bildirdiği alan adı
/// doğrulanamadığı için kullanılmaz; kayıt yine uygulamaya bağlanır.
final class SaveBinding {
  const new({this.url, this.app});

  final String? url;
  final LoginApp? app;
}

SaveBinding saveBindingFor(AutofillTarget target) {
  final webDomain = target.webDomain;
  if (webDomain != null) {
    final host = DomainName.normalize(webDomain);
    if (host == null) return const SaveBinding();
    final scheme = switch (target.webScheme?.toLowerCase()) {
      'http' => 'http',
      _ => 'https',
    };
    return SaveBinding(url: '$scheme://$host');
  }
  final certs = target.certsSha256;
  if (certs.isEmpty ||
      !certs.every(LoginApp.isValidCertDigest) ||
      !LoginApp.isValidPackageName(target.packageName)) {
    return const SaveBinding();
  }
  return SaveBinding(
    app: LoginApp(packageName: target.packageName, certsSha256: certs),
  );
}

/// Yeni kayıt için önerilen ad: sitenin adı veya uygulamanın adı.
String suggestedLoginName(AutofillTarget target) {
  final webDomain = target.webDomain;
  if (webDomain != null) {
    final host = DomainName.normalize(webDomain) ?? webDomain;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
  return target.appLabel ?? target.packageName;
}

/// Eşleşen kayıtlar arasında aynı kullanıcı adını taşıyan ilk kayıt.
///
/// Kullanıcı adı boşsa yalnızca kullanıcı adı boş bir kayıt eşleşir; böylece
/// başka bir hesabın parolası yanlışlıkla değişmez.
LoginItem? existingLoginFor(LoginMatches matches, AutofillSave save) {
  final username = save.username.trim();
  for (final match in matches.matches) {
    if (match.item.content.username.trim() == username) return match.item;
  }
  return null;
}
