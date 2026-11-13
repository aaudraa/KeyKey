import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/record_avatar.dart';
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
  new(this.icons, {this.fail = false});

  final Map<String, Uint8List> icons;
  final bool fail;

  @override
  Future<Uint8List?> appIcon(String packageName) async {
    if (fail) throw StateError('simge okunamadı');
    return icons[packageName];
  }

  @override
  Future<String> versionName() async => '1.0.0';
}

final _app = LoginApp(packageName: 'com.example.oyun', certsSha256: ['a' * 64]);

Future<void> _pump(
  WidgetTester tester,
  _FakePackages packages,
  LoginContent? login,
  String name,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appPackagesProvider.overrideWithValue(packages)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: RecordAvatar(login: login, name: name),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('avatarInitial', () {
    test('kırpılmış adın ilk harfi, büyük', () {
      expect(avatarInitial('  posta '), 'P');
      expect(avatarInitial('9gag'), '9');
    });

    test('boş adda soru işareti', () {
      expect(avatarInitial(''), '?');
      expect(avatarInitial('   '), '?');
    });

    test('emoji yarım kalmaz', () {
      expect(avatarInitial('👨‍👩‍👧 aile'), '👨‍👩‍👧');
    });
  });

  testWidgets('bağlı uygulamanın simgesi gösterilir', (tester) async {
    await _pump(
      tester,
      _FakePackages({'com.example.oyun': _png}),
      LoginContent(name: 'Oyun', apps: [_app]),
      'Oyun',
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('O'), findsNothing);
    // Kutusuz ve renkli (proje sahibinin telefondaki isteği): kırpma ve
    // renk süzgeci yok.
    expect(find.byType(ClipRRect), findsNothing);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('simge okunamazsa baş harfe düşülür', (tester) async {
    await _pump(
      tester,
      _FakePackages({}, fail: true),
      LoginContent(name: 'Oyun', apps: [_app]),
      'Oyun',
    );
    expect(find.byType(Image), findsNothing);
    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('bağlı uygulama yoksa baş harf, ekran okuyucu okumaz', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakePackages({}), null, 'GitHub');
    expect(find.text('G'), findsOneWidget);
    expect(find.bySemanticsLabel('G'), findsNothing);
    expect(tester.getSize(find.byType(RecordAvatar)), const Size(34, 34));
    handle.dispose();
  });

  testWidgets('baş harf ince çizgili dairede, renkli kutu yok', (tester) async {
    await _pump(tester, _FakePackages({}), null, 'GitHub');
    final ink = AppTheme.light.colorScheme.onSurface;
    final text = tester.widget<Text>(find.text('G'));
    expect(text.style?.color, ink);
    final box = tester.widget<DecoratedBox>(
      find.ancestor(of: find.text('G'), matching: find.byType(DecoratedBox)),
    );
    final decoration = box.decoration as ShapeDecoration;
    expect(decoration.color, isNull);
    final shape = decoration.shape as CircleBorder;
    expect(shape.side.color, ink);
    expect(shape.side.width, 1.2);
  });
}
