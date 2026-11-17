import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/l10n/generated/app_localizations_en.dart';
import 'package:keykey/l10n/generated/app_localizations_tr.dart';

/// Sayı içeren İngilizce metinlerde tekil biçim. Türkçede ad sayıdan sonra
/// tekil kaldığı için ayrı biçim gerekmez.
void main() {
  final en = AppLocalizationsEn();
  final tr = AppLocalizationsTr();

  test('geri yükleme özeti', () {
    expect(
      en.restoreSummary('Nov 7', 1, 1),
      'Backup from Nov 7: 1 password and 1 2FA account.',
    );
    expect(
      en.restoreSummary('Nov 7', 2, 0),
      'Backup from Nov 7: 2 passwords and 0 2FA accounts.',
    );
    expect(
      tr.restoreSummary('7 Kas', 1, 2),
      '7 Kas tarihli yedek: 1 parola ve 2 2FA hesabı.',
    );
  });
}
