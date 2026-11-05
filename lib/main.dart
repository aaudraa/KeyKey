import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/bootstrap.dart';
import 'package:keykey/app/licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerDataLicenses();
  final overrides = await bootstrap();
  runApp(ProviderScope(overrides: overrides, child: const KeyKeyApp()));
}
