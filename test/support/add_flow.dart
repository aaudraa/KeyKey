import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/add_panel.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';

/// Menüdeki "+" ile yeni parola formunu açar.
Future<void> openAddPassword(
  WidgetTester tester, {
  Future<void> Function()? settle,
}) async {
  final wait = settle ?? tester.pumpAndSettle;
  await tester.tap(find.byKey(GlassNavBar.addKey));
  await wait();
  await tester.tap(find.text('Parola'));
  await wait();
}

/// Menüdeki "+" ile "2FA kodu"nu seçer ve [way] satırına dokunur (ör.
/// "Anahtarı elle gir").
Future<void> openAddOtp(
  WidgetTester tester,
  String way, {
  Future<void> Function()? settle,
}) async {
  final wait = settle ?? tester.pumpAndSettle;
  await tester.tap(find.byKey(GlassNavBar.addKey));
  await wait();
  await tester.tap(find.text('2FA kodu'));
  await wait();
  // Boş 2FA ekranında aynı adlı kısayol da var; paneldekine dokunulur.
  await tester.tap(
    find.descendant(of: find.byType(AddPanel), matching: find.text(way)),
  );
  await wait();
}
