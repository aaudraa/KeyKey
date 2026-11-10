import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/record_watermark.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/features/vault/data/login_content.dart';

/// 1×1 saydam PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final class _FakePackages implements AppPackages {
  new(this.icons);

  final Map<String, Uint8List> icons;
  final requested = <String>[];

  @override
  Future<Uint8List?> appIcon(String packageName) async {
    requested.add(packageName);
    return icons[packageName];
  }

  @override
  Future<String> versionName() async => '1.0.0';
}

final _app = LoginApp(packageName: 'com.example.oyun', certsSha256: ['a' * 64]);

Future<void> _pump(
  WidgetTester tester,
  _FakePackages packages,
  LoginContent login,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appPackagesProvider.overrideWithValue(packages)],
      child: MaterialApp(
        home: Scaffold(body: RecordWatermark(login: login)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bağlı uygulamanın simgesi gösterilir', (tester) async {
    final packages = _FakePackages({'com.example.oyun': _png});
    await _pump(tester, packages, LoginContent(name: 'Oyun', apps: [_app]));

    expect(packages.requested, ['com.example.oyun']);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.language_outlined), findsNothing);
  });

  testWidgets('simge okunamazsa ve sitesi varsa küre çizgi simgesi', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakePackages({}),
      LoginContent(
        name: 'Oyun',
        apps: [_app],
        urls: const ['https://oyun.example.com'],
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.language_outlined), findsOneWidget);
  });

  testWidgets('uygulaması ve sitesi olmayan kayıtta anahtar simgesi', (
    tester,
  ) async {
    final packages = _FakePackages({});
    await _pump(tester, packages, const LoginContent(name: 'Wi-Fi'));

    expect(packages.requested, isEmpty);
    expect(find.byIcon(Icons.key_outlined), findsOneWidget);
  });

  testWidgets('varsayılan sağlayıcı simge vermez, çizgi simgeye düşer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RecordWatermark(
              login: LoginContent(name: 'O', apps: [_app]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.key_outlined), findsOneWidget);
  });
}
