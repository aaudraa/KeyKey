import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/save_draft.dart';

void main() {
  const cert =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  group('saveBindingFor', () {
    test('http sayfası http olarak bağlanıyor', () {
      final binding = saveBindingFor(
        const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'Giris.Example.com',
          webScheme: 'HTTP',
        ),
      );
      expect(binding.url, 'http://giris.example.com');
      expect(binding.app, isNull);
    });

    test('bilinmeyen şema https sayılıyor', () {
      final binding = saveBindingFor(
        const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'example.com',
          webScheme: 'javascript',
        ),
      );
      expect(binding.url, 'https://example.com');
    });

    test('geçersiz alan adı bağlanmıyor', () {
      final binding = saveBindingFor(
        const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'kötü alan',
        ),
      );
      expect(binding.url, isNull);
      expect(binding.app, isNull);
    });

    test('imzası okunamayan uygulama bağlanmıyor', () {
      expect(
        saveBindingFor(const AutofillTarget(packageName: 'com.ornek.app')).app,
        isNull,
      );
      expect(
        saveBindingFor(
          const AutofillTarget(
            packageName: 'com.ornek.app',
            certsSha256: ['x'],
          ),
        ).app,
        isNull,
      );
    });

    test('uygulama paket adı ve imzasıyla bağlanıyor', () {
      final app = saveBindingFor(
        const AutofillTarget(packageName: 'com.ornek.app', certsSha256: [cert]),
      ).app;
      expect(app?.packageName, 'com.ornek.app');
      expect(app?.certsSha256, [cert]);
    });
  });

  test('önerilen ad', () {
    expect(
      suggestedLoginName(
        const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'www.example.com',
        ),
      ),
      'example.com',
    );
    expect(
      suggestedLoginName(
        const AutofillTarget(packageName: 'com.ornek.app', appLabel: 'Örnek'),
      ),
      'Örnek',
    );
    expect(
      suggestedLoginName(const AutofillTarget(packageName: 'com.ornek.app')),
      'com.ornek.app',
    );
  });
}
