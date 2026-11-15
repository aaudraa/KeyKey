import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/settings/data/theme_preference.dart';

/// Seçimi saklayan depo. `bootstrap` dosyalı depoyu verir; testlerde
/// hiçbir şey yazılmaz.
final themePreferenceStoreProvider = Provider<ThemePreferenceStore>(
  (ref) => const _NoThemePreferenceStore(),
);

/// Açılışta dosyadan okunan seçim.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

/// Uygulamanın teması: sistem, açık ya da koyu.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  /// Yazmalar sırayla yapılır: arka arkaya iki seçim dosyaya aynı anda
  /// yazılıp içeriği karıştırmasın.
  Future<void> _lastWrite = Future.value();

  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  /// Seçimi hemen uygular, sonra saklar. Dosyaya yazılamazsa seçim bu
  /// oturumda yine geçerlidir; bir sonraki açılışta eski tema gelir.
  Future<void> select(ThemeMode mode) {
    state = mode;
    final store = ref.read(themePreferenceStoreProvider);
    return _lastWrite = _lastWrite.then((_) async {
      try {
        await store.write(mode);
      } on FileSystemException {
        // Tema gizli ya da önemli bir bilgi değil; yazılamaması işi
        // durdurmaz.
      }
    });
  }
}

final class _NoThemePreferenceStore implements ThemePreferenceStore {
  const new();

  @override
  Future<void> write(ThemeMode mode) async {}
}
