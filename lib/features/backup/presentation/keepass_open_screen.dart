import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_key.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_reader.dart';
import 'package:keykey/features/backup/data/import/kdbx/platform_kdbx_kdf.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// KeePass (`.kdbx`) dosyasını ana parola ve isteğe bağlı anahtar dosyasıyla
/// açar; açılınca içe aktarma önizlemesine geçer.
///
/// Dosyanın baytları ve anahtar dosyasının özeti yalnızca bellekte durur ve
/// ekran kapanınca sıfırlanır. Parola ve anahtar dosyası hiçbir yere
/// kaydedilmez. Kurallar KeePass içe aktarma tasarımında.
class KeepassOpenScreen extends ConsumerStatefulWidget {
  const new({required this.file, super.key});

  final Uint8List file;

  @override
  ConsumerState<KeepassOpenScreen> createState() => _KeepassOpenScreenState();
}

class _KeepassOpenScreenState extends ConsumerState<KeepassOpenScreen> {
  final _password = TextEditingController();
  Uint8List? _keyFileKey;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    widget.file.fillRange(0, widget.file.length, 0);
    _wipeKeyFile();
    _password.dispose();
    super.dispose();
  }

  void _wipeKeyFile() {
    final key = _keyFileKey;
    if (key != null) key.fillRange(0, key.length, 0);
    _keyFileKey = null;
  }

  Future<void> _pickKeyFile() async {
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(externalActivityGateProvider.notifier)
        .run(
          () => ref
              .read(documentFilesProvider)
              .open(mimeTypes: const ['*/*'], maxBytes: maxKeyFileBytes),
        );
    if (result case DocumentOpened(:final bytes)) {
      String? error;
      Uint8List? key;
      try {
        key = keyFileKey(bytes);
      } on KdbxException catch (e) {
        error = _message(l10n, e);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      if (!mounted) {
        key?.fillRange(0, key.length, 0);
        return;
      }
      setState(() {
        _wipeKeyFile();
        _keyFileKey = key;
        _error = error;
      });
    } else if (result is DocumentTooLarge && mounted) {
      setState(() => _error = l10n.keepassKeyFileCorrupt);
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final export = await KdbxReader.open(
        widget.file,
        kdf: ref.read(kdbxKdfProvider),
        password: _password.text.isEmpty ? null : _password.text,
        keyFileKey: _keyFileKey,
      );
      if (!mounted) return;
      // Önizlemeden geri dönülünce ayarlara gelinir; bu ekran kapanır ve
      // dosyanın baytları sıfırlanır.
      context.pushReplacement(AppRoutes.loginImport, extra: export);
    } on KdbxException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(l10n, e);
        });
      }
    }
  }

  static String _message(AppLocalizations l10n, KdbxException error) =>
      switch (error) {
        KdbxWrongKey() => l10n.keepassWrongKey,
        KdbxUnsupported(:final what, innerStream: true) =>
          l10n.keepassUnsupported(l10n.keepassInnerStream(what)),
        KdbxUnsupported(:final what) =>
          what == 'KeePass 1' ? l10n.keepassOld : l10n.keepassUnsupported(what),
        KdbxTooHeavy() => l10n.keepassTooHeavy,
        KdbxOutOfMemory() => l10n.keepassOutOfMemory,
        KdbxDeviceFailure() => l10n.keepassDeviceFailure,
        KdbxCorrupt() => l10n.keepassCorrupt,
        KdbxKeyFileCorrupt() => l10n.keepassKeyFileCorrupt,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final keyFileChosen = _keyFileKey != null;
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.keepassOpenTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.keepassOpenIntro),
              const SizedBox(height: 16),
              GlassSurface(
                padding: const EdgeInsets.all(4),
                child: SecretField(
                  controller: _password,
                  label: l10n.keepassPassword,
                  autofocus: true,
                  enabled: !_busy,
                  onSubmitted: (_) => unawaited(_open()),
                ),
              ),
              const SizedBox(height: 12),
              GlassSurface(
                child: ListTile(
                  leading: Icon(
                    keyFileChosen
                        ? Icons.key_rounded
                        : Icons.file_open_outlined,
                    color: KkGlass.of(context).accent,
                  ),
                  title: Text(
                    keyFileChosen
                        ? l10n.keepassKeyFileChosen
                        : l10n.keepassKeyFile,
                  ),
                  onTap: _busy || keyFileChosen
                      ? null
                      : () => unawaited(_pickKeyFile()),
                  trailing: keyFileChosen
                      ? IconButton(
                          tooltip: l10n.keepassKeyFileRemove,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _busy
                              ? null
                              : () => setState(_wipeKeyFile),
                        )
                      : null,
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(error, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : () => unawaited(_open()),
                child: Text(l10n.keepassOpen),
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(l10n.keepassOpening, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
