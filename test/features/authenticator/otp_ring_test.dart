import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_ambient.dart';
import 'package:keykey/features/authenticator/presentation/otp_ring.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

Widget _host(Duration remaining, {bool ambient = true, bool disable = false}) =>
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: KkAmbient(
          enabled: ambient,
          child: Center(child: OtpRing(remaining: remaining, period: 30)),
        ),
      ),
    );

double _scale(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(OtpRing),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[0];

void main() {
  testWidgets('son 5 saniyede her saniye hafifçe atar (%100 → %112)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const Duration(seconds: 5)));
    await tester.pumpWidget(_host(const Duration(seconds: 4)));
    await tester.pump();
    await tester.pump(OtpRing.pulse ~/ 2);
    expect(_scale(tester), closeTo(OtpRing.pulseScale, 0.01));
    await tester.pump(OtpRing.pulse);
    expect(_scale(tester), closeTo(1, 0.001));
    // Bir sonraki saniye yeniden.
    await tester.pumpWidget(_host(const Duration(seconds: 3)));
    await tester.pump();
    await tester.pump(OtpRing.pulse ~/ 2);
    expect(_scale(tester), closeTo(OtpRing.pulseScale, 0.01));
    await tester.pumpAndSettle();
  });

  testWidgets('uyarı süresi dışında atmaz', (tester) async {
    await tester.pumpWidget(_host(const Duration(seconds: 12)));
    await tester.pumpWidget(_host(const Duration(seconds: 11)));
    await tester.pump();
    await tester.pump(OtpRing.pulse ~/ 2);
    expect(_scale(tester), 1);
  });

  testWidgets('animasyonlar kapalıyken ya da yaşayan hareket yokken atmaz', (
    tester,
  ) async {
    for (final (ambient, disable) in [(true, true), (false, false)]) {
      await tester.pumpWidget(
        _host(const Duration(seconds: 5), ambient: ambient, disable: disable),
      );
      await tester.pumpWidget(
        _host(const Duration(seconds: 4), ambient: ambient, disable: disable),
      );
      await tester.pump();
      await tester.pump(OtpRing.pulse ~/ 2);
      expect(_scale(tester), 1);
    }
  });
}
