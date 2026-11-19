import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/last_saved.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/application/vault_entries.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:keykey/features/vault/presentation/card_input_formatters.dart';
import 'package:keykey/features/vault/presentation/folder_suggestions.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Yeni kart ([idHex] `null`) ya da var olan kartın düzenlenmesi.
class CardEditScreen extends ConsumerStatefulWidget {
  const new({this.idHex, super.key});

  final String? idHex;

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  final _name = TextEditingController();
  final _cardholder = TextEditingController();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _securityCode = TextEditingController();
  final _pin = TextEditingController();
  final _folder = TextEditingController();
  final _notes = TextEditingController();
  final _expiryFocus = FocusNode();

  /// Kullanıcı son kullanma kutusundan çıktı ya da kaydetmeyi denedi: yarım
  /// tarih artık uyarıyla gösterilir.
  bool _expiryTouched = false;

  CardItem? _original;
  bool _initialized = false;
  bool _dirty = false;
  bool _saving = false;
  bool _done = false;

  bool get _isNew => widget.idHex == null;

  List<TextEditingController> get _all => [
    _name,
    _cardholder,
    _number,
    _expiry,
    _securityCode,
    _pin,
    _folder,
    _notes,
  ];

  @override
  void initState() {
    super.initState();
    _expiryFocus.addListener(_expiryFocusChanged);
  }

  @override
  void dispose() {
    _expiryFocus
      ..removeListener(_expiryFocusChanged)
      ..dispose();
    for (final controller in _all) {
      controller.dispose();
    }
    super.dispose();
  }

  void _expiryFocusChanged() {
    if (!_expiryFocus.hasFocus && _expiry.text.isNotEmpty && !_expiryTouched) {
      setState(() => _expiryTouched = true);
    }
  }

  void _fill(CardItem? item) {
    final content = item?.content;
    _original = item;
    if (content != null) {
      _name.text = content.name;
      _cardholder.text = content.cardholder;
      _number.text = groupCardNumber(content.number);
      _expiry.text = content.expiry?.format() ?? '';
      _securityCode.text = content.securityCode;
      _pin.text = content.pin;
      _folder.text = content.folder ?? '';
      _notes.text = content.notes;
    }
    _initialized = true;
  }

  String get _digits => normalizeCardNumber(_number.text) ?? '';

  /// Boş ya da geçerli `AA/YY`; yarım ya da geçersizse `false`.
  bool get _expiryValid =>
      _expiry.text.isEmpty || CardExpiry.tryParse(_expiry.text) != null;

  /// Yarım ya da geçersiz son kullanma düğmeyi kapatmaz: basınca uyarı
  /// çıkar, böylece kullanıcı neden kaydedilmediğini görür.
  bool get _canSave => _name.text.trim().isNotEmpty || _digits.isNotEmpty;

  /// Diğer kayıtlardaki klasörler; düzenlenen kartın kendisi sayılmaz.
  List<String> get _folders => switch (ref.read(vaultEntriesProvider)) {
    VaultEntriesLoaded(:final entries) => foldersOfEntries(
      entries.where(
        (entry) =>
            _original == null ||
            loginIdHex(entry.id) != loginIdHex(_original!.id),
      ),
    ),
    VaultEntriesLoading() => const [],
  };

  CardContent _collect() {
    final folder = _folder.text.trim();
    final base = CardContent(
      name: _name.text.trim(),
      cardholder: _cardholder.text.trim(),
      number: _digits,
      expiry: CardExpiry.tryParse(_expiry.text),
      securityCode: _securityCode.text,
      pin: _pin.text,
      notes: _notes.text,
      folder: folder.isEmpty ? null : folder,
    );
    final original = _original?.content;
    if (original == null) return base;
    return base.copyWith(
      favorite: original.favorite,
      trashedAt: original.trashedAt,
    );
  }

  Future<void> _save() async {
    if (_saving || _done || !_canSave) return;
    if (!_expiryValid) {
      setState(() => _expiryTouched = true);
      _expiryFocus.requestFocus();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final controller = ref.read(cardsControllerProvider.notifier);
    setState(() => _saving = true);
    try {
      final content = _collect();
      final original = _original;
      final saved = original == null
          ? await controller.add(content)
          : await controller.update(original, content);
      _dirty = false;
      ref
          .read(lastSavedProvider.notifier)
          .mark(savedCardKey(loginIdHex(saved.id)));
      if (mounted) setState(() => _done = true);
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on Exception {
      snack(l10n.loginSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    return await showKkConfirm(
      context,
      title: l10n.loginDiscardTitle,
      confirmLabel: l10n.loginDiscard,
      cancelLabel: l10n.loginKeepEditing,
      destructive: true,
    );
  }

  void _changed(String _) {
    setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(cardsControllerProvider);
    if (!_initialized) {
      if (state is! RecordsLoaded<CardContent>) {
        return const KkScaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      final item = _isNew ? null : findRecord(state, widget.idHex!);
      if (!_isNew && item == null) {
        return KkScaffold(
          appBar: kkAppBar(context),
          body: Center(child: Text(l10n.loginNotFound)),
        );
      }
      _fill(item);
    }
    final digits = _digits;
    final brand = detectCardBrand(digits);
    final numberSuspicious =
        digits.isNotEmpty && (digits.length < 12 || !passesLuhn(digits));
    final expiryError =
        !_expiryValid && (_expiry.text.length == 5 || _expiryTouched);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          context.pop();
        }
      },
      child: KkScaffold(
        appBar: kkAppBar(
          context,
          title: _isNew ? l10n.cardNewTitle : l10n.loginEditTitle,
        ),
        bottomNavigationBar: KkBottomAction(
          label: l10n.loginSave,
          busy: _saving,
          done: _done,
          onDone: () {
            if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
              context.pop();
            }
          },
          onPressed: _canSave ? _save : null,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KkFieldCard(
                child: SecretField(
                  controller: _name,
                  label: l10n.loginName,
                  obscure: false,
                  autofocus: _isNew,
                  textInputAction: TextInputAction.next,
                  onChanged: _changed,
                ),
              ),
              KkFieldCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SecretField(
                      controller: _cardholder,
                      label: l10n.cardholder,
                      obscure: false,
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                    const SizedBox(height: 12),
                    SecretField(
                      controller: _number,
                      label: l10n.cardNumber,
                      obscure: false,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [CardNumberInputFormatter()],
                      helperText: numberSuspicious
                          ? l10n.cardNumberWarning
                          : null,
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                      trailing: brand == null
                          ? null
                          : Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 12,
                              ),
                              child: Text(brand.label),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SecretField(
                            controller: _expiry,
                            focusNode: _expiryFocus,
                            label: l10n.cardExpiry,
                            obscure: false,
                            keyboardType: TextInputType.number,
                            inputFormatters: const [ExpiryInputFormatter()],
                            errorText: expiryError
                                ? l10n.cardExpiryInvalid
                                : null,
                            textInputAction: TextInputAction.next,
                            onChanged: _changed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SecretField(
                            controller: _securityCode,
                            label: l10n.cardSecurityCode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                CardContent.maxSecurityCodeDigits,
                              ),
                            ],
                            textInputAction: TextInputAction.next,
                            onChanged: _changed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SecretField(
                      controller: _pin,
                      label: l10n.cardPin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                          CardContent.maxPinDigits,
                        ),
                      ],
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                  ],
                ),
              ),
              KkFieldCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SecretField(
                      controller: _folder,
                      label: l10n.loginFolder,
                      obscure: false,
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                    FolderSuggestions(
                      folders: _folders,
                      controller: _folder,
                      onPicked: (folder) {
                        _folder.text = folder;
                        _changed(folder);
                      },
                    ),
                  ],
                ),
              ),
              KkFieldCard(
                child: SecretField(
                  controller: _notes,
                  label: l10n.loginNotes,
                  obscure: false,
                  multiline: true,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  onChanged: _changed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
