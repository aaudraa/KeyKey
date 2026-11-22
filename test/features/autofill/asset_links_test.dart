import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/domain/asset_links.dart';

const _fp =
    '14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:'
    '16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5';
const _hex = '146de983c5730650d8eeb9952f34fc6416a08342e61dbea88a0496b23fcf44e5';

String _statement({
  List<String> relation = const ['delegate_permission/common.get_login_creds'],
  String namespace = 'android_app',
  String package = 'com.github.android',
  List<String> fingerprints = const [_fp],
}) => jsonEncode([
  {
    'relation': relation,
    'target': {
      'namespace': namespace,
      'package_name': package,
      'sha256_cert_fingerprints': fingerprints,
    },
  },
]);

void main() {
  test('get_login_creds ifadesi özetleri verir', () {
    expect(assetLinkFingerprints(_statement(), 'com.github.android'), [_hex]);
  });

  test('handle_all_urls de kabul edilir', () {
    expect(
      assetLinkFingerprints(
        _statement(
          relation: const ['delegate_permission/common.handle_all_urls'],
        ),
        'com.github.android',
      ),
      [_hex],
    );
  });

  test('başka ilişki, paket ya da namespace boş verir', () {
    expect(
      assetLinkFingerprints(
        _statement(relation: const ['delegate_permission/common.other']),
        'com.github.android',
      ),
      isEmpty,
    );
    expect(assetLinkFingerprints(_statement(), 'com.sahte.android'), isEmpty);
    expect(
      assetLinkFingerprints(_statement(namespace: 'web'), 'com.github.android'),
      isEmpty,
    );
  });

  test('biçimi bozuk özet atılır', () {
    expect(
      assetLinkFingerprints(
        _statement(fingerprints: [_fp.substring(3), 'ZZ', _fp]),
        'com.github.android',
      ),
      [_hex],
    );
  });

  test('bozuk JSON ve dizi olmayan kök boş verir', () {
    for (final text in ['{}', '[', 'null', '', '[1, "a", null]']) {
      expect(
        assetLinkFingerprints(text, 'com.github.android'),
        isEmpty,
        reason: text,
      );
    }
    expect(
      assetLinkFingerprints(
        jsonEncode([
          {'relation': 'x', 'target': 5},
          {
            'relation': ['delegate_permission/common.get_login_creds'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.github.android',
              'sha256_cert_fingerprints': 'tek',
            },
          },
        ]),
        'com.github.android',
      ),
      isEmpty,
    );
  });
}
