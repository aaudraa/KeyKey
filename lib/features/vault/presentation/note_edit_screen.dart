import 'package:flutter/material.dart';
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
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:keykey/features/vault/presentation/folder_suggestions.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/utf8_length_formatter.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Yeni not ([idHex] `null`) ya da var olan notun düzenlenmesi.
class NoteEditScreen extends ConsumerStatefulWidget {
  const new({this.idHex, super.key});

  final String? idHex;

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  final _name = TextEditingController();
  final _text = TextEditingController();
  final _folder = TextEditingController();

  NoteItem? _original;
  bool _initialized = false;
  bool _dirty = false;
  bool _saving = false;
  bool _done = false;

  bool get _isNew => widget.idHex == null;

  bool get _canSave =>
      _name.text.trim().isNotEmpty || _text.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    _folder.dispose();
    super.dispose();
  }

  void _fill(NoteItem? item) {
    final content = item?.content;
    _original = item;
    if (content != null) {
      _name.text = content.name;
      _text.text = content.text;
      _folder.text = content.folder ?? '';
    }
    _initialized = true;
  }

  /// Diğer kayıtlardaki klasörler; düzenlenen notun kendisi sayılmaz.
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

  NoteContent _collect() {
    final folder = _folder.text.trim();
    final original = _original?.content;
    return NoteContent(
      name: _name.text.trim(),
      text: _text.text,
      folder: folder.isEmpty ? null : folder,
      favorite: original?.favorite ?? false,
      trashedAt: original?.trashedAt,
    );
  }

  Future<void> _save() async {
    if (_saving || _done || !_canSave) return;
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final controller = ref.read(notesControllerProvider.notifier);
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
          .mark(savedNoteKey(loginIdHex(saved.id)));
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
    final state = ref.watch(notesControllerProvider);
    if (!_initialized) {
      if (state is! RecordsLoaded<NoteContent>) {
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
          title: _isNew ? l10n.noteNewTitle : l10n.loginEditTitle,
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
                child: SecretField(
                  controller: _text,
                  label: l10n.noteText,
                  obscure: false,
                  multiline: true,
                  maxLines: 12,
                  inputFormatters: const [
                    Utf8LengthLimitingFormatter(NoteContent.maxTextBytes),
                  ],
                  textInputAction: TextInputAction.newline,
                  onChanged: _changed,
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
            ],
          ),
        ),
      ),
    );
  }
}
