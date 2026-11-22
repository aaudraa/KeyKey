import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/vault/presentation/folder_suggestions.dart';

void main() {
  test('yalnızca harf büyüklüğü (Türkçe İ/ı dahil) farkı eşleşiyor', () {
    expect(matchExistingFolder('iş', ['İş']), 'İş');
    expect(matchExistingFolder('ışık', ['IŞIK']), 'IŞIK');
    expect(matchExistingFolder('BANKA', ['Banka']), 'Banka');
  });

  test('farklı harfler eşleşmiyor', () {
    // Arama şapkaları ve Türkçe harfleri düzleştirir; klasör adında "Kür" ile
    // "Kur" ayrı kelimeler.
    expect(matchExistingFolder('Kur', ['Kür']), 'Kur');
    expect(matchExistingFolder('is', ['İş']), 'is');
    expect(matchExistingFolder('ISIK', ['ışık']), 'ISIK');
  });
}
