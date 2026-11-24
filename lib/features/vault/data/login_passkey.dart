import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:keykey/features/autofill/domain/domain_name.dart';

/// Parola kaydına bağlı bir passkey (WebAuthn kimlik bilgisi).
///
/// Özel anahtar P-256, PKCS#8 DER; kasanın içinde, kaydın geri kalanıyla
/// birlikte şifreli durur. Biçim güvenlik tasarımının "Passkey" bölümünde.
@immutable
final class LoginPasskey {
  new({
    required Uint8List credentialId,
    required this.rpId,
    required Uint8List userHandle,
    required this.userName,
    required this.userDisplayName,
    required Uint8List privateKey,
    required this.createdAt,
  }) : credentialId = Uint8List.fromList(credentialId),
       userHandle = Uint8List.fromList(userHandle),
       privateKey = Uint8List.fromList(privateKey) {
    if (credentialId.isEmpty || credentialId.length > maxCredentialIdBytes) {
      throw ArgumentError.value(credentialId.length, 'credentialId');
    }
    if (userHandle.length > maxUserHandleBytes) {
      throw ArgumentError.value(userHandle.length, 'userHandle');
    }
    if (!isValidRpId(rpId)) throw ArgumentError.value(rpId, 'rpId');
    if (privateKey.isEmpty) throw ArgumentError.value(0, 'privateKey');
  }

  /// WebAuthn'ın kimlik sınırı.
  static const maxCredentialIdBytes = 255;

  /// WebAuthn'ın `user.id` sınırı.
  static const maxUserHandleBytes = 64;

  final Uint8List credentialId;
  final String rpId;
  final Uint8List userHandle;
  final String userName;
  final String userDisplayName;
  final Uint8List privateKey;
  final DateTime createdAt;

  /// `rpId` küçük harfli, geçerli bir ASCII alan adı olmalı; IP adresi
  /// olamaz.
  static bool isValidRpId(String rpId) =>
      rpId.isNotEmpty &&
      DomainName.normalize(rpId) == rpId &&
      !DomainName.isIpAddress(rpId);

  /// Kimliğin base64url biçimi (dolgusuz); listelerde anahtar olarak da
  /// kullanılır.
  String get credentialIdB64 => base64UrlNoPad(credentialId);

  static const keys = {
    'credentialId',
    'rpId',
    'userHandle',
    'userName',
    'userDisplayName',
    'privateKey',
    'createdAt',
  };

  Map<String, Object?> toJson() => {
    'credentialId': credentialIdB64,
    'rpId': rpId,
    'userHandle': base64UrlNoPad(userHandle),
    'userName': userName,
    'userDisplayName': userDisplayName,
    'privateKey': base64.encode(privateKey),
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  /// Değerler `LoginContent` okuyucusunda türleri denetlenmiş gelir.
  /// Geçersiz base64, uzunluk ya da `rpId` `null` döner.
  static LoginPasskey? tryParse(Map<String, Object?> json) {
    final Uint8List id;
    final Uint8List handle;
    final Uint8List key;
    try {
      id = base64UrlDecodeNoPad(json['credentialId']! as String);
      handle = base64UrlDecodeNoPad(json['userHandle']! as String);
      key = base64.decode(json['privateKey']! as String);
    } on FormatException {
      return null;
    }
    final rpId = json['rpId']! as String;
    if (id.isEmpty ||
        id.length > maxCredentialIdBytes ||
        handle.length > maxUserHandleBytes ||
        key.isEmpty ||
        !isValidRpId(rpId)) {
      return null;
    }
    return LoginPasskey(
      credentialId: id,
      rpId: rpId,
      userHandle: handle,
      userName: json['userName']! as String,
      userDisplayName: json['userDisplayName']! as String,
      privateKey: key,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt']! as int,
        isUtc: true,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LoginPasskey &&
      listEquals(other.credentialId, credentialId) &&
      other.rpId == rpId &&
      listEquals(other.userHandle, userHandle) &&
      other.userName == userName &&
      other.userDisplayName == userDisplayName &&
      listEquals(other.privateKey, privateKey) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(rpId, Object.hashAll(credentialId));
}

/// Dolgusuz base64url (WebAuthn JSON'unun biçimi).
String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Dolgulu ya da dolgusuz base64url okur; standart base64'ün `+` ve `/`
/// işaretlerini kabul etmez. Geçersizse [FormatException].
Uint8List base64UrlDecodeNoPad(String text) {
  if (!_base64Url.hasMatch(text)) {
    throw const FormatException('Geçersiz base64url.');
  }
  final unpadded = text.replaceAll('=', '');
  return base64Url.decode(base64Url.normalize(unpadded));
}

final _base64Url = RegExp(r'^[A-Za-z0-9_-]*={0,2}$');
