import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/features/generator/presentation/password_strength_meter.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

Widget _host(String password) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PasswordStrengthMeter(password: password)),
  ),
);

double _bar(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

void main() {
  testWidgets('güç değişince çubuk boyu yumuşak kayar', (tester) async {
    await tester.pumpWidget(_host('a'));
    await tester.pumpAndSettle();
    final start = _bar(tester);
    await tester.pumpWidget(_host('Kq7!vZ2#pL9@wX4%'));
    await tester.pump();
    await tester.pump(KkMotion.base ~/ 2);
    final middle = _bar(tester);
    await tester.pumpAndSettle();
    final end = _bar(tester);
    expect(end, greaterThan(start));
    expect(middle, greaterThan(start));
    expect(middle, lessThan(end));
  });
}
