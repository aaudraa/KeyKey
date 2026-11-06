import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/features/authenticator/presentation/login_picker.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/authenticator/presentation/secret_key_formatter.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// 2FA hesabı ekleme ve düzenleme. [idHex] yoksa yeni hesap oluşturur.
///
/// [initial] verilirse form onunla dolu açılır, örneğin QR'dan okunan hesap.
/// Kullanıcı kaydedene kadar hiçbir şey diske yazılmaz.
class OtpEditScreen extends ConsumerStatefulWidget {
  const new({this.idHex, this.initial, super.key});

  final String? idHex;
  final OtpauthAccount? initial;

  @override
  ConsumerState<OtpEditScreen> createState() => _OtpEditScreenState();
}

class _OtpEditScreenState extends ConsumerState<OtpEditScreen> {
  final _issuer = TextEditingController();
  final _account = TextEditingController();
  final _secret = TextEditingController();
  final _period = TextEditingController();
  final _counter = TextEditingController();
  final _notes = TextEditingController();

  OtpKind _kind = OtpKind.totp;
  OtpAlgorithm _algorithm = OtpAlgorithm.sha1;
  int _digits = OtpParameters.defaultDigits;

  OtpItem? _original;

  /// Eşleştirilen parola kaydı.
  Uint8List? _loginId;
  bool _initialized = false;
  bool _dirty = false;
  bool _saving = false;
  bool _showAdvanced = false;

  /// Kaydetmeye basıldıktan sonra hatalar gösterilir.
  bool _validate = false;
  String? _linkError;

  bool get _isNew => widget.idHex == null;

  @override
  void dispose() {
    for (final controller in [
      _issuer,
      _account,
      _secret,
      _period,
      _counter,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(OtpItem? item) {
    _original = item;
    final content = item?.content;
    final initial = widget.initial;
    if (content != null) {
      _issuer.text = content.issuer;
      _loginId = content.loginId;
      _account.text = content.account;
      _notes.text = content.notes;
      _setParameters(content.parameters);
    } else if (initial != null) {
      _applyAccount(initial);
    } else {
      _period.text = '${OtpParameters.defaultPeriod}';
      _counter.text = '0';
    }
    _initialized = true;
  }

  void _setParameters(OtpParameters parameters) {
    _secret.text = SecretKeyFormatter.group(Base32.encode(parameters.secret));
    _kind = parameters.kind;
    _algorithm = parameters.algorithm;
    _digits = parameters.digits;
    _period.text = '${parameters.period ?? OtpParameters.defaultPeriod}';
    _counter.text = '${parameters.counter ?? 0}';
    _showAdvanced =
        parameters.kind != OtpKind.totp ||
        parameters.algorithm != OtpAlgorithm.sha1 ||
        parameters.digits != OtpParameters.defaultDigits ||
        parameters.period != OtpParameters.defaultPeriod;
  }

  void _applyAccount(OtpauthAccount account) {
    _issuer.text = account.issuer;
    _account.text = account.account;
    _setParameters(account.parameters);
  }

  /// Anahtar kutusuna `otpauth://` bağlantısı yapıştırılırsa formu doldurur.
  void _onSecretChanged(String text) {
    _changed(text);
    final trimmed = text.trim();
    if (!trimmed.toLowerCase().startsWith('otpauth://')) {
      // Her karakterde yeniden çizilir; yanlış karakter hatası yazarken
      // güncellenir.
      setState(() => _linkError = null);
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      final account = OtpauthUri.parse(trimmed);
      setState(() {
        _linkError = null;
        _applyAccount(account);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.otpLinkFilled)));
    } on InvalidOtpauthUriException catch (error) {
      setState(() {
        _linkError = error.error == OtpauthError.unsupportedType
            ? l10n.otpLinkUnsupported
            : l10n.otpLinkInvalid;
      });
    }
  }

  void _changed(String _) {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Alfabe dışı karakter yazıldıysa hangisi olduğunu söyleyen hata. Yazarken
  /// hemen gösterilir; kaydetmeye basmak beklenmez.
  String? _foreignCharacterError(AppLocalizations l10n) {
    final text = _secret.text.trim();
    if (text.toLowerCase().startsWith('otpauth:')) return null;
    final character = Base32.firstForeignCharacter(text);
    if (character == null) return null;
    final rune = character.runes.first;
    // Görünmeyen veya yön değiştiren karakterler mesaja yazılmaz.
    final printable =
        (rune >= 0x21 && rune <= 0x7e) || (rune >= 0xc0 && rune <= 0x24f);
    return switch (character) {
      '0' => l10n.otpSecretLooksLike(character, 'O'),
      '8' => l10n.otpSecretLooksLike(character, 'B'),
      '1' => l10n.otpSecretOneLooksLike,
      _ when printable => l10n.otpSecretForeignCharacter(character),
      _ => l10n.otpSecretInvalid,
    };
  }

  Uint8List? _parsedSecret() {
    try {
      final secret = Base32.decodeLenient(_secret.text);
      return OtpParameters.isValidSecretLength(secret.length) ? secret : null;
    } on FormatException {
      return null;
    }
  }

  int? _parsedPeriod() {
    final value = int.tryParse(_period.text.trim());
    return value != null && OtpParameters.isValidPeriod(value) ? value : null;
  }

  int? _parsedCounter() {
    final value = int.tryParse(_counter.text.trim());
    return value != null && OtpParameters.isValidCounter(value) ? value : null;
  }

  bool get _hasName =>
      _issuer.text.trim().isNotEmpty || _account.text.trim().isNotEmpty;

  /// Form geçerliyse kaydedilecek içerik, değilse `null`.
  OtpContent? _collect() {
    final secret = _parsedSecret();
    if (secret == null || !_hasName || _linkError != null) return null;
    final OtpParameters parameters;
    switch (_kind) {
      case OtpKind.totp:
        final period = _parsedPeriod();
        if (period == null) return null;
        parameters = OtpParameters.totp(
          secret: secret,
          algorithm: _algorithm,
          digits: _digits,
          period: period,
        );
      case OtpKind.hotp:
        final counter = _parsedCounter();
        if (counter == null) return null;
        parameters = OtpParameters.hotp(
          secret: secret,
          algorithm: _algorithm,
          digits: _digits,
          counter: counter,
        );
    }
    final base = _original?.content ?? OtpContent(parameters: parameters);
    return base.copyWith(
      parameters: parameters,
      issuer: _issuer.text.trim(),
      account: _account.text.trim(),
      notes: _notes.text,
      // Parola kaydı silindiyse eşleşme de kalkar. Kayıtlar henüz
      // yüklenmediyse bilinemez, eşleşmeye dokunulmaz.
      loginId: _linkGone() ? null : _loginId,
    );
  }

  /// Eşleştirilen parola kaydı. Kayıt silinmişse eşleşme yok sayılır.
  LoginItem? _linkedLogin() {
    final id = _loginId;
    if (id == null) return null;
    return findLogin(ref.read(loginsControllerProvider), loginIdHex(id));
  }

  bool _linkGone() =>
      _loginId != null &&
      ref.read(loginsControllerProvider) is LoginsLoaded &&
      _linkedLogin() == null;

  Future<void> _chooseLogin() async {
    final picked = await pickLogin(context, linked: _linkedLogin() != null);
    if (picked == null || !mounted) return;
    setState(() {
      _loginId = switch (picked) {
        LoginPicked(:final id) => id,
        LoginUnlinked() => null,
      };
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final content = _collect();
    if (content == null) {
      setState(() {
        _validate = true;
        // Hatalı alan gelişmiş bölümdeyse görünür olsun.
        if (_parsedPeriod() == null || _parsedCounter() == null) {
          _showAdvanced = true;
        }
      });
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(otpsControllerProvider.notifier);
    setState(() => _saving = true);
    try {
      final original = _original;
      if (original == null) {
        await controller.add(content);
      } else {
        await controller.update(original, content);
      }
      _dirty = false;
      if (mounted) context.pop();
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on Exception {
      // Hesap bu sırada silinmiş olabilir: OtpNotFoundException.
      messenger.showSnackBar(SnackBar(content: Text(l10n.loginSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.loginDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.loginKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.loginDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(otpsControllerProvider);
    // Eşleşen kaydın adı, kayıtlar yüklenince görünsün.
    ref.watch(loginsControllerProvider);
    if (!_initialized) {
      if (state is! OtpsLoaded) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final item = _isNew ? null : findOtp(state, widget.idHex!);
      if (!_isNew && item == null) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(l10n.loginNotFound)),
        );
      }
      _fill(item);
    }

    final secretError =
        _linkError ??
        _foreignCharacterError(l10n) ??
        (_validate && _parsedSecret() == null ? l10n.otpSecretInvalid : null);
    final nameError = _validate && !_hasName ? l10n.otpNameRequired : null;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.otpNewTitle : l10n.loginEditTitle),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.loginSave),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SecretField(
              controller: _issuer,
              label: l10n.otpIssuer,
              obscure: false,
              autofocus: _isNew && widget.initial == null,
              errorText: nameError,
              textInputAction: TextInputAction.next,
              onChanged: _changed,
            ),
            const SizedBox(height: 12),
            SecretField(
              controller: _account,
              label: l10n.otpAccount,
              obscure: false,
              textInputAction: TextInputAction.next,
              onChanged: _changed,
            ),
            const SizedBox(height: 12),
            SecretField(
              controller: _secret,
              label: l10n.otpSecret,
              helperText: l10n.otpSecretHelper,
              errorText: secretError,
              // Elle eklenen yeni anahtar servisin ekranından okunarak
              // yazılır; körlemesine yazmak hataya yol açıyordu.
              initiallyVisible: _isNew && widget.initial == null,
              inputFormatters: [SecretKeyFormatter()],
              // Eş genişlikli yazı tipinde 0 ile O, 1 ile I daha kolay
              // ayrılır.
              style: const TextStyle(fontFamily: 'monospace'),
              textInputAction: TextInputAction.next,
              onChanged: _onSecretChanged,
            ),
            const SizedBox(height: 12),
            SecretField(
              controller: _notes,
              label: l10n.loginNotes,
              obscure: false,
              multiline: true,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              onChanged: _changed,
            ),
            const SizedBox(height: 8),
            _LinkedLoginField(
              name: switch (_linkedLogin()) {
                final login? =>
                  login.content.name.trim().isEmpty
                      ? '—'
                      : login.content.name.trim(),
                null => null,
              },
              onTap: _chooseLogin,
            ),
            ExpansionTile(
              key: ValueKey(_showAdvanced),
              initiallyExpanded: _showAdvanced,
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.otpAdvanced),
              subtitle: Text(l10n.otpAdvancedHint),
              onExpansionChanged: (expanded) => _showAdvanced = expanded,
              childrenPadding: const EdgeInsets.only(bottom: 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: _advanced(l10n),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _advanced(AppLocalizations l10n) {
    final periodError =
        _validate && _kind == OtpKind.totp && _parsedPeriod() == null
        ? l10n.otpPeriodInvalid(OtpParameters.maxPeriod)
        : null;
    final counterError =
        _validate && _kind == OtpKind.hotp && _parsedCounter() == null
        ? l10n.otpCounterInvalid
        : null;
    return [
      Text(l10n.otpType, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      SegmentedButton<OtpKind>(
        segments: [
          ButtonSegment(value: OtpKind.totp, label: Text(l10n.otpTypeTotp)),
          ButtonSegment(value: OtpKind.hotp, label: Text(l10n.otpTypeHotp)),
        ],
        selected: {_kind},
        onSelectionChanged: (selection) => setState(() {
          _kind = selection.single;
          _dirty = true;
        }),
      ),
      const SizedBox(height: 16),
      Text(l10n.otpAlgorithm, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      SegmentedButton<OtpAlgorithm>(
        segments: [
          for (final algorithm in OtpAlgorithm.values)
            ButtonSegment(value: algorithm, label: Text(algorithm.label)),
        ],
        selected: {_algorithm},
        onSelectionChanged: (selection) => setState(() {
          _algorithm = selection.single;
          _dirty = true;
        }),
      ),
      const SizedBox(height: 16),
      Text(l10n.otpDigits, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      SegmentedButton<int>(
        segments: [
          for (
            var digits = OtpParameters.minDigits;
            digits <= OtpParameters.maxDigits;
            digits++
          )
            ButtonSegment(value: digits, label: Text('$digits')),
        ],
        selected: {_digits},
        onSelectionChanged: (selection) => setState(() {
          _digits = selection.single;
          _dirty = true;
        }),
      ),
      const SizedBox(height: 16),
      if (_kind == OtpKind.totp)
        _NumberField(
          controller: _period,
          label: l10n.otpPeriod,
          errorText: periodError,
          onChanged: _changed,
        )
      else
        _NumberField(
          controller: _counter,
          label: l10n.otpCounter,
          errorText: counterError,
          onChanged: _changed,
        ),
    ];
  }
}

class _NumberField extends StatelessWidget {
  const new({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Eşleştirilen parola kaydını gösterir, dokununca seçtirir.
class _LinkedLoginField extends StatelessWidget {
  const new({required this.name, required this.onTap});

  /// Eşleşme yoksa `null`.
  final String? name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(name == null ? Icons.link_off : Icons.link),
      title: Text(l10n.otpLinkedLogin),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name ?? l10n.otpLinkNone),
          Text(l10n.otpLinkHint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
