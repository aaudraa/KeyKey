import 'package:flutter/foundation.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';

/// İçe aktarılabilecek bir kayıt.
final class LoginImportCandidate {
  const new({
    required this.content,
    required this.duplicate,
    this.otp,
    this.otpAlreadySaved = false,
  });

  final LoginContent content;

  /// Kasada adresi, kullanıcı adı ve parolası aynı bir kayıt var. Varsayılan
  /// olarak seçilmez.
  final bool duplicate;

  /// Kayda bağlanacak 2FA hesabı; kayıt eklenince bağlanır.
  final OtpContent? otp;

  /// Aynı gizli anahtar kasada zaten var; 2FA hesabı yeniden eklenmez.
  final bool otpAlreadySaved;
}

/// İçe aktarılabilecek bir kart ya da not.
final class RecordImportCandidate<C> {
  const new({
    required this.content,
    required this.duplicate,
    this.adjusted = false,
  });

  final C content;

  /// Kasada aynısı var: kartta ad ve numara, notta ad ve metin. Varsayılan
  /// olarak seçilmez.
  final bool duplicate;

  /// Biçime uymayan bir değer kartın notuna taşındı.
  final bool adjusted;
}

/// Dosyadan çıkarılan, kaydedilmeye hazır liste.
final class LoginImportPlan {
  const new({
    required this.source,
    required this.candidates,
    required this.skipped,
    required this.skippedOtps,
    this.cards = const [],
    this.notes = const [],
  });

  final LoginExportSource source;
  final List<LoginImportCandidate> candidates;
  final List<RecordImportCandidate<CardContent>> cards;
  final List<RecordImportCandidate<NoteContent>> notes;

  /// Parola, kart ve notların toplamı.
  int get total => candidates.length + cards.length + notes.length;

  /// Desteklenmeyen veya bozuk satırlar.
  final int skipped;

  /// Okunamayan veya desteklenmeyen (örneğin Yandex) 2FA anahtarları. Kaydın
  /// kendisi yine eklenir.
  final int skippedOtps;
}

/// Okunan dosyayı kasadaki kayıtlarla karşılaştırıp listeyi hazırlar.
LoginImportPlan planLoginImport(
  LoginExport export, {
  required Iterable<LoginItem> existingLogins,
  required Iterable<OtpItem> existingOtps,
  Iterable<CardItem> existingCards = const [],
  Iterable<NoteItem> existingNotes = const [],
}) {
  final knownCards = {
    for (final item in existingCards)
      (item.content.name.trim(), item.content.number),
  };
  final knownNotes = {
    for (final item in existingNotes)
      (item.content.name.trim(), item.content.text),
  };
  final known = {for (final item in existingLogins) _fingerprint(item.content)};
  final secrets = {
    for (final item in existingOtps) _secretKey(item.content.parameters.secret),
  };
  final candidates = <LoginImportCandidate>[];
  var skippedOtps = 0;
  for (final login in export.logins) {
    final content = LoginContent(
      name: login.name,
      username: login.username,
      password: login.password,
      urls: login.urls,
      notes: login.notes,
      folder: login.folder,
      favorite: login.favorite,
      customFields: [
        for (final field in login.fields)
          LoginCustomField(
            name: field.name,
            value: field.value,
            hidden: field.hidden,
          ),
      ],
    );
    OtpContent? otp;
    final totp = login.totp;
    if (totp != null) {
      otp = otpFromImport(totp, issuer: login.name, account: login.username);
      if (otp == null) skippedOtps++;
    }
    // Yalnızca kasadaki anahtar sayılır. Dosyada iki kez geçen anahtarı
    // hangisinin taşıyacağı seçime bağlı; kaydederken [importedOtps] seçer.
    final otpAlreadySaved =
        otp != null && secrets.contains(_secretKey(otp.parameters.secret));
    // Kasadaki her girişle karşılaştırılır; bir kez hesaplanır.
    final fingerprint = _fingerprint(content);
    candidates.add(
      LoginImportCandidate(
        content: content,
        duplicate: known.any((other) => other.matches(fingerprint)),
        otp: otp,
        otpAlreadySaved: otpAlreadySaved,
      ),
    );
  }
  return LoginImportPlan(
    source: export.source,
    candidates: candidates,
    cards: [
      for (final card in export.cards)
        RecordImportCandidate(
          content: card.content,
          duplicate: knownCards.contains((
            card.content.name.trim(),
            card.content.number,
          )),
          adjusted: card.adjusted,
        ),
    ],
    notes: [
      for (final note in export.notes)
        RecordImportCandidate(
          content: note,
          duplicate: knownNotes.contains((note.name.trim(), note.text)),
        ),
    ],
    skipped: export.skipped,
    skippedOtps: skippedOtps,
  );
}

/// Seçilen adayların 2FA hesapları, sırasıyla eklenen kayıtlara ([loginIds])
/// bağlı. Kasada zaten olan anahtar eklenmez; seçilenler arasında aynı anahtar
/// bir kez, ilk seçilenle eklenir.
List<OtpContent> importedOtps(
  List<LoginImportCandidate> chosen,
  List<Uint8List> loginIds,
) {
  final added = <String>{};
  return [
    for (final (index, candidate) in chosen.indexed)
      if (candidate.otp case final otp?
          when !candidate.otpAlreadySaved &&
              added.add(_secretKey(otp.parameters.secret)))
        otp.copyWith(loginId: loginIds[index]),
  ];
}

/// `otpauth://` bağlantısını, Bitwarden'ın `steam://` Steam anahtarını veya
/// çıplak Base32 anahtarı 2FA hesabına çevirir. Okunamıyorsa veya
/// desteklenmiyorsa `null`.
@visibleForTesting
OtpContent? otpFromImport(
  String text, {
  required String issuer,
  required String account,
}) {
  final trimmed = text.trim();
  if (trimmed.toLowerCase().startsWith('otpauth://')) {
    try {
      final parsed = OtpauthUri.parse(trimmed);
      return OtpContent(
        parameters: parsed.parameters,
        issuer: parsed.issuer.isEmpty ? issuer : parsed.issuer,
        account: parsed.account.isEmpty ? account : parsed.account,
      );
    } on InvalidOtpauthUriException {
      return null;
    }
  }
  const steamPrefix = 'steam://';
  final steam = trimmed.toLowerCase().startsWith(steamPrefix);
  final List<int> secret;
  try {
    secret = Base32.decodeLenient(
      steam ? trimmed.substring(steamPrefix.length) : trimmed,
    );
  } on FormatException {
    // Tanınmayan biçimler de buraya düşer.
    return null;
  }
  if (!OtpParameters.isValidSecretLength(secret.length)) return null;
  return OtpContent(
    parameters: steam
        ? OtpParameters.steam(secret: secret)
        : OtpParameters.totp(secret: secret),
    issuer: issuer,
    account: account,
  );
}

String _secretKey(List<int> secret) => secret.join(',');

/// Yinelenen kayıt karşılaştırması: kullanıcı adı ve parola aynı, adreslerden
/// biri ortak ya da ikisinde de adres yok.
final class _Fingerprint {
  const new(this.username, this.password, this.urls);

  final String username;
  final String password;
  final Set<String> urls;

  bool matches(_Fingerprint other) =>
      username == other.username &&
      password == other.password &&
      (urls.isEmpty && other.urls.isEmpty || urls.any(other.urls.contains));
}

_Fingerprint _fingerprint(LoginContent content) => _Fingerprint(
  content.username.trim(),
  content.password,
  {for (final url in content.urls) _normalizeUrl(url)},
);

String _normalizeUrl(String url) {
  var value = url.trim().toLowerCase();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}
