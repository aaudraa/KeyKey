import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
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
  final List<_CustomFieldControllers> _customFields = [];

  LoginItem? _original;
  bool _initialized = false;
  bool _dirty = false;
  bool _saving = false;

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

  void _changed(String _) {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    if (!_initialized) {
      if (state is! LoginsLoaded) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final item = _isNew ? null : findLogin(state, widget.idHex!);
      if (!_isNew && item == null) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(l10n.loginNotFound)),
        );
      }
      _fill(item);
    }

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
          title: Text(_isNew ? l10n.loginNewTitle : l10n.loginEditTitle),
          actions: [
            ListenableBuilder(
              listenable: _name,
              builder: (context, _) => TextButton(
                onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
                child: Text(l10n.loginSave),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SecretField(
              controller: _name,
              label: l10n.loginName,
              obscure: false,
              autofocus: _isNew,
              textInputAction: TextInputAction.next,
              onChanged: _changed,
            ),
            const SizedBox(height: 12),
            SecretField(
              controller: _username,
              label: l10n.loginUsername,
              obscure: false,
              textInputAction: TextInputAction.next,
              onChanged: _changed,
            ),
            const SizedBox(height: 12),
            SecretField(
              controller: _password,
              label: l10n.loginPassword,
              textInputAction: TextInputAction.next,
              onChanged: _changed,
            ),
            const SizedBox(height: 12),
            for (final (index, url) in _urls.indexed) ...[
              Row(
                children: [
                  Expanded(
                    child: SecretField(
                      controller: url,
                      label: l10n.loginUrl,
                      obscure: false,
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.loginRemoveUrl,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() {
                      _urls.removeAt(index).dispose();
                      _dirty = true;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _urls.add(TextEditingController());
                }),
                icon: const Icon(Icons.add_link),
                label: Text(l10n.loginAddUrl),
              ),
            ),
            const SizedBox(height: 12),
            SecretField(
              controller: _folder,
              label: l10n.loginFolder,
              obscure: false,
              textInputAction: TextInputAction.next,
              onChanged: _changed,
            ),
            const SizedBox(height: 12),
            SecretField(
              controller: _notes,
              label: l10n.loginNotes,
              obscure: false,
              multiline: true,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              onChanged: _changed,
            ),
            const SizedBox(height: 16),
            for (final (index, field) in _customFields.indexed) ...[
              Row(
                children: [
                  Expanded(
                    child: SecretField(
                      controller: field.name,
                      label: l10n.loginFieldName,
                      obscure: false,
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SecretField(
                      controller: field.value,
                      label: l10n.loginFieldValue,
                      obscure: field.hidden,
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                  ),
                  IconButton(
                    tooltip: field.hidden
                        ? l10n.loginFieldVisible
                        : l10n.loginFieldHidden,
                    icon: Icon(
                      field.hidden ? Icons.lock_outline : Icons.lock_open,
                    ),
                    onPressed: () => setState(() {
                      field.hidden = !field.hidden;
                      _dirty = true;
                    }),
                  ),
                  IconButton(
                    tooltip: l10n.loginRemoveField,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() {
                      _customFields.removeAt(index).dispose();
                      _dirty = true;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _customFields.add(_CustomFieldControllers());
                }),
                icon: const Icon(Icons.add),
                label: Text(l10n.loginAddField),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
