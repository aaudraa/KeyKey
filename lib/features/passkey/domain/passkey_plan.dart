import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:keykey/features/autofill/domain/domain_name.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/passkey/domain/passkey_caller.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Kasaya bakmadan çözülmüş passkey isteği: hangi site, hangi origin.
@immutable
final class PasskeyPrompt {
  const new({
    required this.caller,
    required this.rpId,
    required this.origin,
    this.creation,
    this.assertion,
    this.clientDataHash,
  });

  final PasskeyCaller caller;
  final String rpId;

  /// clientDataJSON'a yazılan origin.
  final String origin;

  /// Oluşturmada dolu.
  final CreationOptions? creation;

  /// Girişte dolu.
  final RequestOptions? assertion;
  final Uint8List? clientDataHash;

  bool get isCreate => creation != null;
}

/// İsteği okur ve `rpId` kuralını uygular. Kurala uymayan istek
/// [PasskeyRequestException].
PasskeyPrompt resolvePasskeyPrompt({
  required bool create,
  required String requestJson,
  required PasskeyCaller caller,
  required PublicSuffixList suffixes,
  Uint8List? clientDataHash,
}) {
  final creation = create ? CreationOptions.parse(requestJson) : null;
  final assertion = create ? null : RequestOptions.parse(requestJson);
  final rpId =
      (creation?.rpId ?? assertion?.rpId ?? defaultRpId(caller)) ??
      (throw const PasskeyRequestException(PasskeyError.invalidRequest));
  if (!rpIdAllowed(rpId, caller, suffixes)) {
    throw const PasskeyRequestException(PasskeyError.rpIdMismatch);
  }
  return PasskeyPrompt(
    caller: caller,
    rpId: rpId,
    origin: caller.origin(),
    creation: creation,
    assertion: assertion,
    clientDataHash: clientDataHash,
  );
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Iterable<LoginItem> _live(Iterable<LoginItem> items) =>
    items.where((item) => !item.content.isTrashed);

/// `excludeCredentials`: site bu hesabın passkey'ini zaten biliyor.
bool alreadyRegistered(
  Iterable<LoginItem> items,
  String rpId,
  List<Uint8List> excludeIds,
) {
  if (excludeIds.isEmpty) return false;
  return _live(items).any(
    (item) => item.content.passkeys.any(
      (passkey) =>
          passkey.rpId == rpId &&
          excludeIds.any((id) => _sameBytes(id, passkey.credentialId)),
    ),
  );
}

/// Passkey'in ekleneceği kayıt adayları: çöp dışı, adresi `rpId`'nin
/// sitesinde ve kullanıcı adı aynı (büyük-küçük harf gözetmeden).
List<LoginItem> createTargets({
  required Iterable<LoginItem> items,
  required String rpId,
  required String userName,
  required PublicSuffixList suffixes,
}) {
  final site = suffixes.registrableDomain(rpId);
  final name = userName.trim().toLowerCase();
  if (site == null || name.isEmpty) return const [];
  return [
    for (final item in _live(items))
      if (item.content.username.trim().toLowerCase() == name &&
          item.content.urls.any((url) {
            final host = DomainName.hostOfUrl(url);
            return host != null && suffixes.registrableDomain(host) == site;
          }))
        item,
  ];
}

/// Girişte kullanılabilecek passkey'ler: çöp dışı kayıtlarda, `rpId`'si
/// aynı; site izin listesi verdiyse yalnızca onlar.
List<(LoginItem, LoginPasskey)> passkeysFor({
  required Iterable<LoginItem> items,
  required String rpId,
  required List<Uint8List> allowIds,
}) {
  return [
    for (final item in _live(items))
      for (final passkey in item.content.passkeys)
        if (passkey.rpId == rpId &&
            (allowIds.isEmpty ||
                allowIds.any((id) => _sameBytes(id, passkey.credentialId))))
          (item, passkey),
  ];
}

/// Kayda passkey ekler. Aynı site ve aynı kullanıcı kimliğindeki eski
/// passkey'in yerine geçer (site hesabı yeniden kaydetti). [app] verilirse
/// ve kayıtta yoksa uygulama da bağlanır.
LoginContent withPasskey(
  LoginContent content,
  LoginPasskey passkey, {
  LoginApp? app,
}) {
  final kept = [
    for (final old in content.passkeys)
      if (old.rpId != passkey.rpId ||
          !_sameBytes(old.userHandle, passkey.userHandle))
        old,
  ];
  if (kept.length >= LoginContent.maxPasskeys) {
    throw const PasskeyRequestException(PasskeyError.tooMany);
  }
  final bound =
      app == null || content.apps.any((a) => a.packageName == app.packageName);
  return content.copyWith(
    passkeys: [...kept, passkey],
    apps: bound ? content.apps : [...content.apps, app],
  );
}

/// Passkey için yeni parola kaydı: ad sitenin adı, adres `https://<rpId>`,
/// parola boş.
LoginContent newPasskeyLogin({
  required CreationOptions options,
  required String rpId,
  required LoginPasskey passkey,
  LoginApp? app,
}) {
  final rpName = options.rpName.trim();
  return LoginContent(
    name: rpName.isEmpty ? rpId : rpName,
    username: options.userName,
    urls: ['https://$rpId'],
    apps: [?app],
    passkeys: [passkey],
  );
}

/// Sistem penceresinde gösterilecek hesap adı; boş olamaz.
String passkeyAccountName(LoginPasskey passkey, LoginItem item) {
  for (final name in [
    passkey.userName,
    passkey.userDisplayName,
    item.content.username,
    item.content.name,
  ]) {
    if (name.trim().isNotEmpty) return name.trim();
  }
  return passkey.rpId;
}
