import 'dart:io';

import 'package:flutter/material.dart';

/// Dosyadaki metni temaya çevirir. Boş ya da tanınmayan içerik sistem
/// teması sayılır.
ThemeMode parseThemeMode(String text) => switch (text.trim()) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// Kullanıcının tema seçimini saklar.
abstract interface class ThemePreferenceStore {
  Future<void> write(ThemeMode mode);
}

/// Tema seçimi kasanın dışında, şifresiz bir dosyada durur: kilit ekranı
/// da seçilen temayla açılsın diye. Gizli bir bilgi değildir; ayrıntı
/// `resources/docs/tema-secimi.md` belgesinde.
final class FileThemePreferenceStore implements ThemePreferenceStore {
  new(this._file);

  final File _file;

  /// Dosya yoksa ya da okunamıyorsa sistem teması.
  Future<ThemeMode> read() async {
    try {
      return parseThemeMode(await _file.readAsString());
    } on FileSystemException {
      return ThemeMode.system;
    } on FormatException {
      return ThemeMode.system;
    }
  }

  @override
  Future<void> write(ThemeMode mode) =>
      _file.writeAsString(mode.name, flush: true);
}
