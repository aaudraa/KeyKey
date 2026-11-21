import 'package:keykey/features/generator/application/password_generator.dart';

/// Parola üreticisinin son kullanılan seçenekleri. Kasanın içindeki ayar
/// kaydında saklanır; üretilen parola saklanmaz.
final class GeneratorPreferences {
  const new({
    this.passphrase = false,
    this.password = const PasswordOptions(),
    this.passphraseOptions = const PassphraseOptions(),
  });

  static const defaults = GeneratorPreferences();

  /// Üretici parola cümlesiyle açılır.
  final bool passphrase;
  final PasswordOptions password;
  final PassphraseOptions passphraseOptions;

  Map<String, Object?> toJson() => {
    'passphrase': passphrase,
    'length': password.length,
    'lowercase': password.lowercase,
    'uppercase': password.uppercase,
    'digits': password.digits,
    'symbols': password.symbols,
    'words': passphraseOptions.words,
  };

  static const _keys = {
    'passphrase',
    'length',
    'lowercase',
    'uppercase',
    'digits',
    'symbols',
    'words',
  };

  /// Biçime ya da sınırlara uymayan içerikte `null` döner. En az bir
  /// karakter türü seçili olmalı; yoksa üretici boş açılırdı.
  static GeneratorPreferences? tryParse(Object? json) {
    if (json is! Map<String, Object?> ||
        json.length != _keys.length ||
        !_keys.containsAll(json.keys)) {
      return null;
    }
    final passphrase = json['passphrase'];
    final length = json['length'];
    final lowercase = json['lowercase'];
    final uppercase = json['uppercase'];
    final digits = json['digits'];
    final symbols = json['symbols'];
    final words = json['words'];
    if (passphrase is! bool ||
        length is! int ||
        lowercase is! bool ||
        uppercase is! bool ||
        digits is! bool ||
        symbols is! bool ||
        words is! int) {
      return null;
    }
    if (length < PasswordOptions.minLength ||
        length > PasswordOptions.maxLength ||
        words < PassphraseOptions.minWords ||
        words > PassphraseOptions.maxWords) {
      return null;
    }
    final password = PasswordOptions(
      length: length,
      lowercase: lowercase,
      uppercase: uppercase,
      digits: digits,
      symbols: symbols,
    );
    if (!password.hasAnyClass) return null;
    return GeneratorPreferences(
      passphrase: passphrase,
      password: password,
      passphraseOptions: PassphraseOptions(words: words),
    );
  }
}
