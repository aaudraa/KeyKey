import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otp_import.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Başka bir uygulamadan okunan hesapları gösterir; kullanıcı seçtiklerini
/// ekler. Hiçbir şey onaydan önce kaydedilmez.
///
/// Gizli anahtarı zaten kayıtlı olan hesaplar işaretlenir ve seçilemez.
class OtpImportScreen extends ConsumerStatefulWidget {
  const new({required this.source, super.key});

  final ImportSource source;

  @override
  ConsumerState<OtpImportScreen> createState() => _OtpImportScreenState();
}

class _OtpImportScreenState extends ConsumerState<OtpImportScreen> {
  final _password = TextEditingController();
  ImportBatch? _batch;
  Set<int> _selected = {};
  bool _opening = false;
  bool _saving = false;
  String? _passwordError;
  bool _selectionReady = false;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    if (source is ReadyImport) _batch = source.batch;
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final source = widget.source;
    if (source is! EncryptedImport || _opening || _password.text.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _opening = true;
      _passwordError = null;
    });
    try {
      final batch = await source.decrypt(_password.text);
      // Türetme sürerken ekran kapanmış olabilir, örneğin kasa kilitlendi;
      // denetleyici o zaman atılmıştır.
      if (!mounted) return;
      _password.clear();
      setState(() => _batch = batch);
    } on WrongImportPasswordException {
      if (mounted) setState(() => _passwordError = l10n.otpImportWrongPassword);
    } on InvalidImportException {
      if (mounted) setState(() => _passwordError = l10n.otpImportFailed);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _save(ImportBatch batch) async {
    if (_saving || _selected.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final contents = [
        for (final index in _selected.toList()..sort())
          contentOf(batch.accounts[index]),
      ];
      final count = await ref
          .read(otpsControllerProvider.notifier)
          .addAll(contents);
      if (mounted) context.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.otpImportDone(count))),
      );
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final batch = _batch;
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.otpImportTitle),
      body: batch == null ? _passwordForm(l10n) : _accounts(l10n, batch),
      bottomNavigationBar: batch == null
          ? KkBottomAction(
              label: l10n.otpImportOpen,
              busy: _opening,
              onPressed: _open,
            )
          : _addButton(l10n, batch),
    );
  }

  Widget? _addButton(AppLocalizations l10n, ImportBatch batch) {
    if (ref.watch(otpsControllerProvider) is! OtpsLoaded) return null;
    return KkBottomAction(
      label: l10n.otpImportAdd(_selected.length),
      busy: _saving,
      onPressed: _selected.isEmpty ? null : () => _save(batch),
    );
  }

  Widget _passwordForm(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.otpImportPasswordHint),
        const SizedBox(height: 16),
        KkFieldCard(
          child: SecretField(
            controller: _password,
            label: l10n.otpImportPassword,
            autofocus: true,
            enabled: !_opening,
            errorText: _passwordError,
            onSubmitted: (_) => _open(),
          ),
        ),
      ],
    );
  }

  Widget _accounts(AppLocalizations l10n, ImportBatch batch) {
    final state = ref.watch(otpsControllerProvider);
    if (state is! OtpsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final duplicates = {
      for (final (index, account) in batch.accounts.indexed)
        if (isAlreadyAdded(account, state.items)) index,
    };
    if (!_selectionReady) {
      // İlk açılışta yeni olanların hepsi seçili gelir.
      _selected = {
        for (var i = 0; i < batch.accounts.length; i++)
          if (!duplicates.contains(i)) i,
      };
      _selectionReady = true;
    }

    return Column(
      children: [
        if (batch.unsupported > 0)
          _Notice(
            icon: Icons.info_outline,
            text: l10n.otpImportUnsupported(batch.unsupported),
          ),
        if (batch.batchSize > 1)
          _Notice(icon: Icons.qr_code_2, text: l10n.otpImportBatch),
        Expanded(
          child: batch.accounts.isEmpty
              ? Center(child: Text(l10n.otpImportEmpty))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemCount: batch.accounts.length,
                  itemBuilder: (context, index) {
                    final account = batch.accounts[index];
                    final duplicate = duplicates.contains(index);
                    final title = account.issuer.isNotEmpty
                        ? account.issuer
                        : account.account.isNotEmpty
                        ? account.account
                        : l10n.otpUnnamed;
                    final subtitle = [
                      if (account.issuer.isNotEmpty &&
                          account.account.isNotEmpty)
                        account.account,
                      if (duplicate) l10n.otpImportDuplicate,
                    ].join(' · ');
                    return GlassSurface(
                      child: CheckboxListTile(
                        value: _selected.contains(index),
                        onChanged: duplicate || _saving
                            ? null
                            : (checked) => setState(() {
                                if (checked ?? false) {
                                  _selected.add(index);
                                } else {
                                  _selected.remove(index);
                                }
                              }),
                        title: Text(title),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassSurface(
        child: ListTile(
          leading: Icon(icon, color: KkGlass.of(context).accent),
          title: Text(text),
        ),
      ),
    );
  }
}
