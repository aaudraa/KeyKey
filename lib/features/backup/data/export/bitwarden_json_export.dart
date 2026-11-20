import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/backup/data/export/bitwarden_totp.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';

/// Kasayı Bitwarden'ın şifresiz JSON biçiminde dışa aktarır.
///
/// CSV'den farkı kartları da taşımasıdır. Alan adları Bitwarden'ınkiler:
/// tür 1 giriş, 2 güvenli not, 3 kart. Çöp kutusundakiler ve parola geçmişi
/// yazılmaz. Bir kayda bağlı 2FA hesabı o kaydın `totp` alanına, bağlı
/// olmayanlar ayrı giriş öğelerine yazılır (CSV'deki kural). Kartın PIN'i
/// `PIN` adlı gizli bir özel alandır; KeyKey'in içe aktarması onu yine PIN'e
/// çevirir.
abstract final class BitwardenJsonExport {
  static String build({
    required Iterable<LoginItem> logins,
    required Iterable<OtpItem> otps,
    required Iterable<CardItem> cards,
    required Iterable<NoteItem> notes,
  }) {
    final liveLogins = [
      for (final item in logins)
        if (!item.content.isTrashed) item,
    ];
    final liveOtps = [
      for (final item in otps)
        if (!item.content.isTrashed) item,
    ];
    final liveCards = [
      for (final item in cards)
        if (!item.content.isTrashed) item,
    ];
    final liveNotes = [
      for (final item in notes)
        if (!item.content.isTrashed) item,
    ];

    final folderIds = <String, String>{};
    String? folderId(String? name) {
      if (name == null || name.isEmpty) return null;
      return folderIds.putIfAbsent(
        name,
        () =>
            '00000000-0000-4000-8000-'
            '${(folderIds.length + 1).toString().padLeft(12, '0')}',
      );
    }

    final items = <Map<String, Object?>>[];
    final linked = <OtpItem>{};
    for (final login in liveLogins) {
      OtpItem? otp;
      for (final candidate in liveOtps) {
        if (!linked.contains(candidate) &&
            listEquals(candidate.content.loginId, login.id)) {
          otp = candidate;
          break;
        }
      }
      if (otp != null) linked.add(otp);
      final content = login.content;
      items.add({
        ..._common(
          id: login.id,
          type: 1,
          name: content.name,
          notes: content.notes,
          folderId: folderId(content.folder),
          favorite: content.favorite,
          fields: [
            for (final field in content.customFields)
              _field(field.name, field.value, hidden: field.hidden),
          ],
        ),
        'login': {
          'uris': [
            for (final url in content.urls) {'match': null, 'uri': url},
            for (final app in content.apps)
              {'match': null, 'uri': 'androidapp://${app.packageName}'},
          ],
          'username': _orNull(content.username),
          'password': _orNull(content.password),
          'totp': otp == null ? null : _otpauth(otp),
        },
      });
    }
    for (final otp in liveOtps) {
      if (linked.contains(otp)) continue;
      final content = otp.content;
      items.add({
        ..._common(
          id: otp.id,
          type: 1,
          name: content.issuer.isNotEmpty ? content.issuer : content.account,
          notes: content.notes,
          folderId: null,
          favorite: content.favorite,
          fields: const [],
        ),
        'login': {
          'uris': const <Object?>[],
          'username': _orNull(content.account),
          'password': null,
          'totp': _otpauth(otp),
        },
      });
    }
    for (final card in liveCards) {
      final content = card.content;
      final expiry = content.expiry;
      items.add({
        ..._common(
          id: card.id,
          type: 3,
          name: content.name,
          notes: content.notes,
          folderId: folderId(content.folder),
          favorite: content.favorite,
          fields: [
            if (content.pin.isNotEmpty)
              _field('PIN', content.pin, hidden: true),
          ],
        ),
        'card': {
          'cardholderName': _orNull(content.cardholder),
          'brand': switch (content.cardBrand) {
            null => null,
            final brand => _bitwardenBrand(brand),
          },
          'number': _orNull(content.number),
          'expMonth': expiry == null ? null : '${expiry.month}',
          'expYear': expiry == null ? null : '${expiry.year}',
          'code': _orNull(content.securityCode),
        },
      });
    }
    for (final note in liveNotes) {
      final content = note.content;
      items.add({
        ..._common(
          id: note.id,
          type: 2,
          name: content.name,
          notes: content.text,
          folderId: folderId(content.folder),
          favorite: content.favorite,
          fields: const [],
        ),
        'secureNote': {'type': 0},
      });
    }

    return const JsonEncoder.withIndent('  ').convert({
      'encrypted': false,
      'folders': [
        for (final MapEntry(key: name, value: id) in folderIds.entries)
          {'id': id, 'name': name},
      ],
      'items': items,
    });
  }

  static Map<String, Object?> _common({
    required Uint8List id,
    required int type,
    required String name,
    required String notes,
    required String? folderId,
    required bool favorite,
    required List<Map<String, Object?>> fields,
  }) => {
    'id': _uuid(id),
    'organizationId': null,
    'folderId': folderId,
    'type': type,
    'reprompt': 0,
    'name': name,
    'notes': _orNull(notes),
    'favorite': favorite,
    'fields': fields,
    'collectionIds': null,
  };

  /// Özel alan: tür 0 metin, 1 gizli.
  static Map<String, Object?> _field(
    String name,
    String value, {
    required bool hidden,
  }) => {
    'name': name,
    'value': value,
    'type': hidden ? 1 : 0,
    'linkedId': null,
  };

  /// Bitwarden'ın marka adları; Troy onda yok.
  static String _bitwardenBrand(CardBrand brand) => switch (brand) {
    CardBrand.visa => 'Visa',
    CardBrand.mastercard => 'Mastercard',
    CardBrand.amex => 'Amex',
    CardBrand.discover => 'Discover',
    CardBrand.jcb => 'JCB',
    CardBrand.unionPay => 'UnionPay',
    CardBrand.maestro => 'Maestro',
    CardBrand.diners => 'Diners Club',
    CardBrand.troy => 'Other',
  };

  static String? _orNull(String value) => value.isEmpty ? null : value;

  /// 16 baytlık kayıt kimliği UUID biçiminde (8-4-4-4-12).
  static String _uuid(Uint8List id) {
    final hex = [for (final byte in id) byte.toRadixString(16).padLeft(2, '0')]
        .join();
    if (hex.length != 32) return hex;
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20),
    ].join('-');
  }

  static String _otpauth(OtpItem item) => bitwardenTotp(item.content);
}
