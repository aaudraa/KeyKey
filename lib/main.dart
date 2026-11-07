import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/bootstrap.dart';
import 'package:keykey/app/licenses.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/presentation/autofill_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerDataLicenses();
  final overrides = await bootstrap();
  runApp(ProviderScope(overrides: overrides, child: const KeyKeyApp()));
}

/// Otomatik doldurma ekranının giriş noktası. Android'deki `AutofillActivity`
/// bunu ayrı bir Flutter motorunda çalıştırır; kasayı kendisi açar.
@pragma('vm:entry-point')
Future<void> autofillMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await bootstrap();
  runApp(
    ProviderScope(
      overrides: [
        ...overrides,
        autofillBridgeProvider.overrideWithValue(PigeonAutofillBridge()),
      ],
      child: const AutofillApp(),
    ),
  );
}
