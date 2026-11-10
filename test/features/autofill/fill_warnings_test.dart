import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/fill_warnings.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

void main() {
  LoginItem item(int id) => LoginItem(
    id: Uint8List.fromList([id]),
    content: const LoginContent(name: 'Kayıt'),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final matched = item(1);
  final other = item(2);
  final fake = item(3);
  final matches = LoginMatches(
    matches: [LoginMatch(matched, LoginMatchKind.app)],
    signatureMismatches: [fake],
  );
  const cert =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  const app = AutofillTarget(
    packageName: 'com.banka.mobil',
    certsSha256: [cert],
  );

  Set<FillWarning> warn(AutofillTarget target, LoginItem chosen) =>
      fillWarnings(target: target, item: chosen, matches: matches);

  test('eşleşen kayıtta uyarı yok', () {
    expect(warn(app, matched), isEmpty);
  });

  test('eşleşmeyen kayıt bağlanabilir', () {
    final warnings = warn(app, other);
    expect(warnings, {FillWarning.noMatch});
    expect(canBindApp(target: app, warnings: warnings), isTrue);
  });

  test('imzası tutmayan kayıt bağlanamaz', () {
    final warnings = warn(app, fake);
    expect(warnings, {FillWarning.signatureMismatch});
    expect(canBindApp(target: app, warnings: warnings), isFalse);
  });

  test('imzası okunamayan uygulama bağlanamaz', () {
    const unknown = AutofillTarget(packageName: 'com.banka.mobil');
    final warnings = warn(unknown, other);
    expect(canBindApp(target: unknown, warnings: warnings), isFalse);
  });

  test('WebView eşleşmeyen kayıtta ek uyarı', () {
    const webView = AutofillTarget(
      packageName: 'com.banka.mobil',
      certsSha256: [cert],
      untrustedWebDomain: 'banka.com.tr',
    );
    expect(warn(webView, other), {FillWarning.noMatch, FillWarning.webView});
    // Uygulamaya bağlı kayıt, WebView'da da uyarısız eşleşir.
    expect(warn(webView, matched), isEmpty);
  });

  test('alan adı bildirmeyen WebView de uyarılıyor', () {
    // Android 14 emülatöründeki WebView alan adını bildirmedi.
    const webView = AutofillTarget(
      packageName: 'com.banka.mobil',
      certsSha256: [cert],
      inWebView: true,
    );
    expect(webView.showsWebPage, isTrue);
    expect(warn(webView, other), {FillWarning.noMatch, FillWarning.webView});
    expect(warn(webView, matched), isEmpty);
  });

  test('tarayıcıda bağlama yok, http uyarılıyor', () {
    const web = AutofillTarget(
      packageName: 'com.android.chrome',
      certsSha256: [cert],
      webDomain: 'banka.com.tr',
      webScheme: 'HTTP',
    );
    final warnings = warn(web, other);
    expect(warnings, {FillWarning.noMatch, FillWarning.insecure});
    expect(canBindApp(target: web, warnings: warnings), isFalse);
  });

  group('directFillCandidate', () {
    LoginMatches only(LoginItem single, LoginMatchKind kind) => LoginMatches(
      matches: [LoginMatch(single, kind)],
      signatureMismatches: const [],
    );
    const browser = AutofillTarget(
      packageName: 'com.android.chrome',
      certsSha256: [cert],
      webDomain: 'github.com',
      webScheme: 'https',
    );

    test('uygulama hedefinde imzası tutan tek kayıt doğrudan dolar', () {
      final result = directFillCandidate(
        target: app,
        matches: only(matched, LoginMatchKind.app),
      );
      expect(result, same(matched));
    });

    test('güvenilen tarayıcıda https ve alan adı tutan tek kayıt '
        'doğrudan dolar', () {
      final result = directFillCandidate(
        target: browser,
        matches: only(matched, LoginMatchKind.sameSite),
      );
      expect(result, same(matched));
    });

    test('iki eşleşmede liste açılır', () {
      final result = directFillCandidate(
        target: app,
        matches: LoginMatches(
          matches: [
            LoginMatch(matched, LoginMatchKind.app),
            LoginMatch(other, LoginMatchKind.app),
          ],
          signatureMismatches: const [],
        ),
      );
      expect(result, isNull);
    });

    test('http sayfada liste açılır', () {
      const insecure = AutofillTarget(
        packageName: 'com.android.chrome',
        certsSha256: [cert],
        webDomain: 'github.com',
        webScheme: 'http',
      );
      final result = directFillCandidate(
        target: insecure,
        matches: only(matched, LoginMatchKind.exactHost),
      );
      expect(result, isNull);
    });

    test('web sayfası gösteren uygulamada liste açılır', () {
      const webView = AutofillTarget(
        packageName: 'com.banka.mobil',
        certsSha256: [cert],
        inWebView: true,
      );
      final result = directFillCandidate(
        target: webView,
        matches: only(matched, LoginMatchKind.app),
      );
      expect(result, isNull);
    });

    test('başka bir kayıtta imza tutmuyorsa liste açılır', () {
      expect(directFillCandidate(target: app, matches: matches), isNull);
    });

    test('eşleşme yoksa liste açılır', () {
      expect(
        directFillCandidate(target: app, matches: LoginMatches.empty),
        isNull,
      );
    });
  });
}
