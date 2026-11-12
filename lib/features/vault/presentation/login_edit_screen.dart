import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/record_avatar.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/generator/presentation/generator_sheet.dart';
import 'package:keykey/features/generator/presentation/password_strength_meter.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/cert_fingerprint.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kayıt ekleme ve düzenleme. [idHex] yoksa yeni kayıt oluşturur.
class LoginEditScreen extends ConsumerStatefulWidget {
  const new({this.idHex, super.key});

  final String? idHex;

  @override
  ConsumerState<LoginEditScreen> createState() => _LoginEditScreenState();
}

class _CustomFieldControllers {
  new({String name = '', String value = '', this.hidden = false})
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;
  bool hidden;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _LoginEditScreenState extends ConsumerState<LoginEditScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _folder = TextEditingController();
  final _notes = TextEditingController();
  final List<TextEditingController> _urls = [];

  /// Otomatik doldurmanın bağladığı uygulamalar. Burada yalnızca kaldırılır.
  final List<LoginApp> _apps = [];
  final List<_CustomFieldControllers> _customFields = [];

  LoginItem? _original;
  bool _initialized = false;
  bool _dirty = false;
  bool _saving = false;

  /// Klasör ve not alanı görünüyor mu: doluysa ya da yongadan eklendiyse.
  bool _showFolder = false;
  bool _showNotes = false;

  /// Yongadan eklenen, ilk çizildiğinde odaklanacak alan ve odağı.
  String? _autofocus;
  final _addedFocus = FocusNode();

  bool get _isNew => widget.idHex == null;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _username,
      _password,
      _folder,
      _notes,
      ..._urls,
    ]) {
      controller.dispose();
    }
    for (final field in _customFields) {
      field.dispose();
    }
    _addedFocus.dispose();
    super.dispose();
  }

  void _fill(LoginItem? item) {
    final content = item?.content ?? const LoginContent(name: '');
    _original = item;
    _name.text = content.name;
    _username.text = content.username;
    _password.text = content.password;
    _folder.text = content.folder ?? '';
    _notes.text = content.notes;
    _urls.addAll([
      for (final url in content.urls) TextEditingController(text: url),
      if (content.urls.isEmpty) TextEditingController(),
    ]);
    _apps.addAll(content.apps);
    _showFolder = _folder.text.isNotEmpty;
    _showNotes = _notes.text.isNotEmpty;
    _customFields.addAll([
      for (final field in content.customFields)
        _CustomFieldControllers(
          name: field.name,
          value: field.value,
          hidden: field.hidden,
        ),
    ]);
    _initialized = true;
  }

  LoginContent _collect() {
    final base = _original?.content ?? const LoginContent(name: '');
    final folder = _folder.text.trim();
    return base.copyWith(
      name: _name.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      urls: [
        for (final url in _urls)
          if (url.text.trim().isNotEmpty) url.text.trim(),
      ],
      apps: List.of(_apps),
      notes: _notes.text,
      folder: folder.isEmpty ? null : folder,
      customFields: [
        for (final field in _customFields)
          if (field.name.text.trim().isNotEmpty || field.value.text.isNotEmpty)
            LoginCustomField(
              name: field.name.text.trim(),
              value: field.value.text,
              hidden: field.hidden,
            ),
      ],
    );
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(loginsControllerProvider.notifier);
    setState(() => _saving = true);
    try {
      final content = _collect();
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
      messenger.showSnackBar(SnackBar(content: Text(l10n.loginSaveFailed)));
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
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Ek alan ekler; eklenen alan ilk çizildiğinde odaklanır.
  void _addExtra(String key, VoidCallback add) {
    setState(() {
      add();
      _autofocus = key;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _addedFocus.requestFocus();
    });
  }

  FocusNode? _focusFor(String key) => _autofocus == key ? _addedFocus : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    if (!_initialized) {
      if (state is! LoginsLoaded) {
        return const KkScaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      final item = _isNew ? null : findLogin(state, widget.idHex!);
      if (!_isNew && item == null) {
        return KkScaffold(
          appBar: kkAppBar(context),
          body: Center(child: Text(l10n.loginNotFound)),
        );
      }
      _fill(item);
    }
    final glass = KkGlass.of(context);
    final theme = Theme.of(context);

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
          title: _isNew ? l10n.loginNewTitle : l10n.loginEditTitle,
          actions: [
            // Kaydın simge kutusu; ad yazıldıkça oluşur.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListenableBuilder(
                listenable: _name,
                builder: (context, _) => RecordAvatar(
                  login: LoginContent(name: _name.text, apps: _apps),
                  name: _name.text,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: _name,
          builder: (context, _) => KkBottomAction(
            label: l10n.loginSave,
            busy: _saving,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ),
        // Form kısa; bütün alanlar hep kurulu kalsın (odak ve kaydırma için).
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
                child: SecretField(
                  controller: _username,
                  label: l10n.loginUsername,
                  obscure: false,
                  textInputAction: TextInputAction.next,
                  onChanged: _changed,
                ),
              ),
              KkFieldCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SecretField(
                      controller: _password,
                      label: l10n.loginPassword,
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ListenableBuilder(
                              listenable: _password,
                              builder: (context, _) => _password.text.isEmpty
                                  ? const SizedBox.shrink()
                                  : PasswordStrengthMeter(
                                      password: _password.text,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: glass.accentContainer,
                              foregroundColor: theme.colorScheme.primary,
                            ),
                            onPressed: () async {
                              final generated = await showGeneratorSheet(
                                context,
                              );
                              if (generated == null) return;
                              _password.text = generated;
                              _changed(generated);
                            },
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(l10n.loginGenerate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final (index, url) in _urls.indexed)
                KkFieldCard(
                  key: ObjectKey(url),
                  onRemove: index == 0
                      ? null
                      : () => setState(() {
                          _urls.removeAt(index).dispose();
                          _dirty = true;
                        }),
                  removeTooltip: l10n.loginRemoveUrl,
                  child: SecretField(
                    controller: url,
                    label: l10n.loginUrl,
                    obscure: false,
                    focusNode: _focusFor('url-$index'),
                    textInputAction: TextInputAction.next,
                    onChanged: _changed,
                  ),
                ),
              for (final (index, app) in _apps.indexed)
                KkFieldCard(
                  onRemove: () => setState(() {
                    _apps.removeAt(index);
                    _dirty = true;
                  }),
                  removeTooltip: l10n.loginRemoveApp,
                  child: ListTile(
                    leading: Icon(Icons.android_rounded, color: glass.accent),
                    title: Text(app.packageName),
                    subtitle: Text(
                      l10n.loginAppSignature(
                        formatCertFingerprint(
                          app.certsSha256.first,
                          short: true,
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              if (_showFolder)
                KkFieldCard(
                  onRemove: () => setState(() {
                    _folder.clear();
                    _showFolder = false;
                    _dirty = true;
                  }),
                  child: SecretField(
                    controller: _folder,
                    label: l10n.loginFolder,
                    obscure: false,
                    focusNode: _focusFor('folder'),
                    textInputAction: TextInputAction.next,
                    onChanged: _changed,
                  ),
                ),
              if (_showNotes)
                KkFieldCard(
                  onRemove: () => setState(() {
                    _notes.clear();
                    _showNotes = false;
                    _dirty = true;
                  }),
                  child: SecretField(
                    controller: _notes,
                    label: l10n.loginNotes,
                    obscure: false,
                    multiline: true,
                    maxLines: 8,
                    focusNode: _focusFor('notes'),
                    textInputAction: TextInputAction.newline,
                    onChanged: _changed,
                  ),
                ),
              for (final (index, field) in _customFields.indexed)
                KkFieldCard(
                  key: ObjectKey(field),
                  onRemove: () => setState(() {
                    _customFields.removeAt(index).dispose();
                    _dirty = true;
                  }),
                  child: Column(
                    children: [
                      SecretField(
                        controller: field.name,
                        label: l10n.loginFieldName,
                        obscure: false,
                        focusNode: _focusFor('field-$index'),
                        textInputAction: TextInputAction.next,
                        onChanged: _changed,
                      ),
                      SecretField(
                        controller: field.value,
                        label: l10n.loginFieldValue,
                        obscure: field.hidden,
                        textInputAction: TextInputAction.next,
                        onChanged: _changed,
                        trailing: IconButton(
                          tooltip: field.hidden
                              ? l10n.loginFieldVisible
                              : l10n.loginFieldHidden,
                          icon: Icon(
                            field.hidden
                                ? Icons.lock_outline_rounded
                                : Icons.lock_open_rounded,
                          ),
                          onPressed: () => setState(() {
                            field.hidden = !field.hidden;
                            _dirty = true;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              KkMoreOptions(
                options: [
                  if (!_showFolder)
                    KkOption(
                      label: l10n.formFolder,
                      onAdd: () =>
                          _addExtra('folder', () => _showFolder = true),
                    ),
                  if (!_showNotes)
                    KkOption(
                      label: l10n.formNote,
                      onAdd: () => _addExtra('notes', () => _showNotes = true),
                    ),
                  KkOption(
                    label: l10n.formCustomField,
                    onAdd: () => _addExtra(
                      'field-${_customFields.length}',
                      () => _customFields.add(_CustomFieldControllers()),
                    ),
                  ),
                  KkOption(
                    label: l10n.formAnotherSite,
                    onAdd: () => _addExtra(
                      'url-${_urls.length}',
                      () => _urls.add(TextEditingController()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
