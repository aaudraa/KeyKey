import 'package:keykey/features/autofill/domain/domain_name.dart';

/// Gömülü liste beklenen biçimde değil. Uygulamanın paketi bozulmuş olabilir.
final class InvalidPublicSuffixListException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'InvalidPublicSuffixListException: $message';
}

/// [Public Suffix List](https://publicsuffix.org/list/) ile kayıt edilebilir
/// alan adını bulur: `giris.banka.com.tr` için `banka.com.tr`.
///
/// Listenin ICANN ve özel bölümlerinin ikisi de kullanılır; böylece
/// `ali.github.io` ile `veli.github.io` ayrı siteler sayılır. Kurallar ve
/// alan adları ASCII (punycode) biçimindedir.
final class PublicSuffixList {
  new _(this._rules, this._wildcards, this._exceptions);

  factory parse(String text) {
    final rules = <String>{};
    final wildcards = <String>{};
    final exceptions = <String>{};
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('//')) continue;
      var rule = line.split(RegExp(r'\s')).first;
      final Set<String> target;
      if (rule.startsWith('!')) {
        rule = rule.substring(1);
        target = exceptions;
      } else if (rule.startsWith('*.')) {
        rule = rule.substring(2);
        target = wildcards;
      } else {
        target = rules;
      }
      final ascii = DomainName.normalize(rule);
      if (ascii == null || rule.contains('*')) {
        throw InvalidPublicSuffixListException('Geçersiz kural: $line');
      }
      target.add(ascii);
    }
    if (rules.length + wildcards.length < minimumRules) {
      throw const InvalidPublicSuffixListException('Beklenmeyen kural sayısı.');
    }
    return PublicSuffixList._(rules, wildcards, exceptions);
  }

  /// Liste bundan az kural içeriyorsa bozuk sayılır.
  static const minimumRules = 5000;

  /// `com.tr` gibi düz kurallar.
  final Set<String> _rules;

  /// `*.kobe.jp` kuralı için `kobe.jp`.
  final Set<String> _wildcards;

  /// `!city.kobe.jp` kuralı için `city.kobe.jp`.
  final Set<String> _exceptions;

  /// [host]'un kayıt edilebilir alan adı. [host] bir genel sonek veya IP
  /// adresiyse, ya da geçersizse `null`.
  String? registrableDomain(String host) {
    final name = DomainName.normalize(host);
    if (name == null || DomainName.isIpAddress(name)) return null;
    final labels = name.split('.');
    final suffixLength = _suffixLength(labels);
    if (labels.length <= suffixLength) return null;
    return labels.sublist(labels.length - suffixLength - 1).join('.');
  }

  /// Genel sonekin etiket sayısı. En uzun eşleşen kural geçerlidir; istisna
  /// kuralı, eşlediği adın en soldaki etiketini sonekten çıkarır. Hiçbir kural
  /// eşleşmezse son etiket sonektir.
  int _suffixLength(List<String> labels) {
    for (var i = 0; i < labels.length; i++) {
      final candidate = labels.sublist(i).join('.');
      final length = labels.length - i;
      if (_exceptions.contains(candidate)) return length - 1;
      if (_rules.contains(candidate)) return length;
      if (length > 1 && _wildcards.contains(labels.sublist(i + 1).join('.'))) {
        return length;
      }
    }
    return 1;
  }
}
