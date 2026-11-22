import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/app_sites.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';

const pslPath = 'resources/assets/autofill/public_suffix_list.dat';

void main() {
  late PublicSuffixList psl;

  setUpAll(() {
    psl = PublicSuffixList.parse(File(pslPath).readAsStringSync());
  });

  group('doğrulanmış siteler', () {
    test('yalnızca doğrulanmış alan adları, kayıt edilebilir alan adı', () {
      expect(
        verifiedSites([
          AppDomain(host: 'login.github.com', verified: true),
          AppDomain(host: '*.ornek.com', verified: true),
          AppDomain(host: 'gitlab.com', verified: false),
          AppDomain(host: '*.github.io', verified: true),
          AppDomain(host: 'com.tr', verified: true),
          AppDomain(host: '192.168.1.1', verified: true),
        ], psl),
        {'github.com', 'ornek.com'},
      );
    });

    test('boş liste', () {
      expect(verifiedSites(const [], psl), isEmpty);
    });
  });

  group('paket adından site', () {
    test('ters parçalardan kayıt edilebilir ilk önek', () {
      expect(siteFromPackageName('com.github.android', psl), 'github.com');
      expect(siteFromPackageName('tr.com.garanti.cep', psl), 'garanti.com.tr');
      expect(
        siteFromPackageName('com.google.android.apps.foo', psl),
        'google.com',
      );
      expect(
        siteFromPackageName('com.amazon.mShop.android.shopping', psl),
        'amazon.com',
      );
    });

    test('kayıt edilebilir önek yoksa null', () {
      expect(siteFromPackageName('tek', psl), isNull);
      expect(siteFromPackageName('com', psl), isNull);
      expect(siteFromPackageName('tr.com', psl), isNull);
      expect(siteFromPackageName('', psl), isNull);
      expect(siteFromPackageName('com.kötü_ad!', psl), isNull);
    });
  });
}
