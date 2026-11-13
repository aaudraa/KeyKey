import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_rolling_text.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_switch.dart';
import 'package:keykey/features/generator/application/password_generator.dart';
import 'package:keykey/features/generator/data/wordlists.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Parola üretici. Seçilen parolayı döndürür, vazgeçilirse `null`.
Future<String?> showGeneratorSheet(BuildContext context) {
  return showKkSheet<String>(
    context,
    builder: (context) => const GeneratorSheet(),
  );
}

enum _Mode { password, passphrase }

class GeneratorSheet extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends ConsumerState<GeneratorSheet> {
  _Mode _mode = _Mode.password;
  PasswordOptions _password = const PasswordOptions();
  PassphraseOptions _passphrase = const PassphraseOptions();
  String _value = '';
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    final random = ref.read(randomSourceProvider);
    switch (_mode) {
      case _Mode.password:
        _value = _password.hasAnyClass
            ? PasswordGenerator.password(_password, random)
            : '';
      case _Mode.passphrase:
        final words = ref.read(effWordlistProvider).value;
        _value = words == null
            ? ''
            : PasswordGenerator.passphrase(_passphrase, words, random);
    }
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _regenerate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = ref.watch(effWordlistProvider);
    if (_mode == _Mode.passphrase && _value.isEmpty && words.hasValue) {
      _regenerate();
    }
    final bits = switch (_mode) {
      _Mode.password => PasswordGenerator.passwordBits(_password),
      _Mode.passphrase => PasswordGenerator.passphraseBits(
        _passphrase,
        words.value?.length ?? 0,
      ),
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_Mode>(
              segments: [
                ButtonSegment(
                  value: _Mode.password,
                  label: Text(l10n.generatorPassword),
                ),
                ButtonSegment(
                  value: _Mode.passphrase,
                  label: Text(l10n.generatorPassphrase),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  _update(() => _mode = selection.single),
            ),
            const SizedBox(height: 16),
            GlassSurface(
              child: ListTile(
                contentPadding: const EdgeInsetsDirectional.fromSTEB(
                  16,
                  8,
                  8,
                  8,
                ),
                // Yeni parola kısa süre karışıp yerine oturur (madde 3.2).
                title: KkScrambleText(
                  text: _value.isEmpty
                      ? '—'
                      : _visible
                      ? _value
                      : '•' * 12,
                  textKey: const Key('generator-value'),
                  // Gizle/göster karıştırmaz; yalnızca yeni parola.
                  trigger: _value,
                  enabled: _visible && _value.isNotEmpty,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(l10n.generatorBits(bits.round())),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _visible ? l10n.secretHide : l10n.secretShow,
                      icon: Icon(
                        _visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _visible = !_visible),
                    ),
                    IconButton(
                      tooltip: l10n.generatorRegenerate,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: KkGlass.of(context).accent,
                      ),
                      onPressed: () => _update(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._options(l10n),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _value.isEmpty
                  ? null
                  : () => Navigator.pop(context, _value),
              child: Text(l10n.generatorUse),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _options(AppLocalizations l10n) {
    switch (_mode) {
      case _Mode.password:
        return [
          Text(l10n.generatorLength(_password.length)),
          Slider(
            value: _password.length.toDouble(),
            min: PasswordOptions.minLength.toDouble(),
            max: PasswordOptions.maxLength.toDouble(),
            divisions: PasswordOptions.maxLength - PasswordOptions.minLength,
            label: '${_password.length}',
            onChanged: (value) => _update(
              () => _password = _password.copyWith(length: value.round()),
            ),
          ),
          KkSwitchTile(
            title: Text(l10n.generatorLowercase),
            value: _password.lowercase,
            onChanged: (value) =>
                _update(() => _password = _password.copyWith(lowercase: value)),
          ),
          KkSwitchTile(
            title: Text(l10n.generatorUppercase),
            value: _password.uppercase,
            onChanged: (value) =>
                _update(() => _password = _password.copyWith(uppercase: value)),
          ),
          KkSwitchTile(
            title: Text(l10n.generatorDigits),
            value: _password.digits,
            onChanged: (value) =>
                _update(() => _password = _password.copyWith(digits: value)),
          ),
          KkSwitchTile(
            title: Text(l10n.generatorSymbols),
            value: _password.symbols,
            onChanged: (value) =>
                _update(() => _password = _password.copyWith(symbols: value)),
          ),
          if (!_password.hasAnyClass) Text(l10n.generatorNeedClass),
        ];
      case _Mode.passphrase:
        return [
          Text(l10n.generatorWords(_passphrase.words)),
          Slider(
            value: _passphrase.words.toDouble(),
            min: PassphraseOptions.minWords.toDouble(),
            max: PassphraseOptions.maxWords.toDouble(),
            divisions: PassphraseOptions.maxWords - PassphraseOptions.minWords,
            label: '${_passphrase.words}',
            onChanged: (value) => _update(
              () => _passphrase = PassphraseOptions(words: value.round()),
            ),
          ),
          Text(l10n.generatorPassphraseNote),
        ];
    }
  }
}
