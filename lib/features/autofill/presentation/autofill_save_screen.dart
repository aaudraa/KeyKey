import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/application/autofill_matches.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/autofill/domain/save_draft.dart';
import 'package:keykey/features/autofill/presentation/autofill_app.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/cert_fingerprint.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Başka bir uygulamaya yazılan girişin kasaya kaydedildiği ekran.
///
/// Kasa açıldıktan sonra gösterilir. Kullanıcı değerleri görür, düzenler ve
/// kaydeder; site veya uygulama kayda kendiliğinden bağlanır. Aynı kullanıcı
/// adıyla eşleşen bir kayıt varsa onun parolasını güncellemek de önerilir.
class AutofillSaveScreen extends ConsumerStatefulWidget {
  const new({required this.target, required this.save, super.key});

  final AutofillTarget target;
  final AutofillSave save;

  @override
  ConsumerState<AutofillSaveScreen> createState() => _AutofillSaveScreenState();
}

class _AutofillSaveScreenState extends ConsumerState<AutofillSaveScreen> {
  late final _name = TextEditingController(
    text: suggestedLoginName(widget.target),
  );
  late final _username = TextEditingController(text: widget.save.username);
  late final _password = TextEditingController(text: widget.save.password);
  late final SaveBinding _binding = saveBindingFor(widget.target);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _addNew() => _run((controller) async {
    final binding = _binding;
    final url = binding.url;
    final app = binding.app;
    await controller.add(
      LoginContent(
        name: _name.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        urls: [?url],
        apps: [?app],
      ),
    );
  });

  /// Eşleşen kaydın parolasını değiştirir; eskisi geçmişe girer.
  Future<void> _updateExisting(LoginItem item) => _run(
    (controller) => controller.update(
      item,
      item.content.copyWith(password: _password.text),
    ),
  );

  /// Kaydeder, kasayı kilitler ve ekranı kapatır.
  Future<void> _run(Future<void> Function(LoginsController) save) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await save(ref.read(loginsControllerProvider.notifier));
    } on VaultLockedException {
      // Kasa kilitlendi; kilit ekranı yeniden açılıyor.
      if (mounted) setState(() => _busy = false);
      return;
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.loginSaveFailed)));
      if (mounted) setState(() => _busy = false);
      return;
    }
    _close();
  }

  void _close() {
    ref.read(autofillDoneProvider.notifier).markDone();
    ref.read(vaultControllerProvider.notifier).lock();
    unawaited(ref.read(autofillBridgeProvider).cancel());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matches = switch (ref.watch(autofillMatchesProvider)) {
      AsyncData(:final value) => value,
      _ => LoginMatches.empty,
    };
    final existing = existingLoginFor(matches, widget.save);
    final app = _binding.app;
    final url = _binding.url;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.autofillSaveTitle),
        leading: IconButton(
          tooltip: l10n.autofillClose,
          icon: const Icon(Icons.close),
          onPressed: () => unawaited(ref.read(autofillBridgeProvider).cancel()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.autofillFor(autofillTargetName(widget.target)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (existing != null) ...[
            _ExistingCard(
              item: existing,
              samePassword: existing.content.password == widget.save.password,
              busy: _busy,
              onUpdate: () => unawaited(_updateExisting(existing)),
              onClose: _close,
            ),
            const SizedBox(height: 16),
          ],
          SecretField(
            controller: _name,
            label: l10n.loginName,
            obscure: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SecretField(
            controller: _username,
            label: l10n.loginUsername,
            obscure: false,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          SecretField(controller: _password, label: l10n.loginPassword),
          const SizedBox(height: 8),
          if (url != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(l10n.autofillSaveSite(url)),
            ),
          if (app != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.android),
              title: Text(
                l10n.autofillSaveApp(widget.target.appLabel ?? app.packageName),
              ),
              subtitle: Text(
                l10n.loginAppSignature(
                  formatCertFingerprint(app.certsSha256.first, short: true),
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          if (widget.target.untrustedWebDomain != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.autofillSaveWebView),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _name.text.trim().isEmpty
                ? null
                : () => unawaited(_addNew()),
            child: Text(l10n.loginSave),
          ),
        ],
      ),
    );
  }
}

class _ExistingCard extends StatelessWidget {
  const new({
    required this.item,
    required this.samePassword,
    required this.busy,
    required this.onUpdate,
    required this.onClose,
  });

  final LoginItem item;
  final bool samePassword;
  final bool busy;
  final VoidCallback onUpdate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = item.content.name.isEmpty ? '—' : item.content.name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              samePassword
                  ? l10n.autofillSaveAlready(name)
                  : l10n.autofillSaveExisting(name),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: samePassword
                  ? FilledButton.tonal(
                      onPressed: onClose,
                      child: Text(l10n.autofillClose),
                    )
                  : FilledButton.tonal(
                      onPressed: busy ? null : onUpdate,
                      child: Text(l10n.autofillSaveUpdate),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
