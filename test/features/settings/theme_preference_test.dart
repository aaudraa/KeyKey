import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/settings/application/theme_controller.dart';
import 'package:keykey/features/settings/data/theme_preference.dart';

class _RecordingStore implements ThemePreferenceStore {
  final written = <ThemeMode>[];

  @override
  Future<void> write(ThemeMode mode) async => written.add(mode);
}

class _FailingStore implements ThemePreferenceStore {
  @override
  Future<void> write(ThemeMode mode) async =>
      throw const FileSystemException('yazılamadı');
}

void main() {
  group('parseThemeMode', () {
    test('bilinen değerleri okur', () {
      expect(parseThemeMode('system'), ThemeMode.system);
      expect(parseThemeMode('light'), ThemeMode.light);
      expect(parseThemeMode('dark'), ThemeMode.dark);
    });

    test('boşluk ve satır sonu kırpılır', () {
      expect(parseThemeMode(' dark\n'), ThemeMode.dark);
    });

    test('boş ya da tanınmayan içerik sistem sayılır', () {
      expect(parseThemeMode(''), ThemeMode.system);
      expect(parseThemeMode('mavi'), ThemeMode.system);
    });
  });

  group('FileThemePreferenceStore', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('kk-tema-'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('dosya yokken sistem', () async {
      final store = FileThemePreferenceStore(File('${dir.path}/theme'));
      expect(await store.read(), ThemeMode.system);
    });

    test('yazılan seçim geri okunur', () async {
      final file = File('${dir.path}/theme');
      final store = FileThemePreferenceStore(file);
      await store.write(ThemeMode.dark);
      expect(await store.read(), ThemeMode.dark);
      expect(file.readAsStringSync(), 'dark');
    });
  });

  group('themeModeProvider', () {
    test('başlangıç değerinden açılır', () {
      final container = ProviderContainer(
        overrides: [initialThemeModeProvider.overrideWithValue(ThemeMode.dark)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('seçim uygulanır ve depoya yazılır', () async {
      final store = _RecordingStore();
      final container = ProviderContainer(
        overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await container.read(themeModeProvider.notifier).select(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(store.written, [ThemeMode.light]);
    });

    test('yazılamazsa seçim yine de oturumda kalır', () async {
      final container = ProviderContainer(
        overrides: [
          themePreferenceStoreProvider.overrideWithValue(_FailingStore()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(themeModeProvider.notifier).select(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });
}
