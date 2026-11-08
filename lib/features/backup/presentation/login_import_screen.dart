import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/backup/application/login_import_plan.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Belge seçiciyle bir parola dışa aktarması seçtirir, okur ve içe aktarma
/// ekranını açar. Dosyanın baytları okunduktan sonra sıfırlanır.
Future<void> pickLoginExport(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void show(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  final files = ref.read(documentFilesProvider);
  final result = await ref
      .read(externalActivityGateProvider.notifier)
      .run(
        () => files.open(
          mimeTypes: const ['*/*'],
          maxBytes: LoginExportReader.maxBytes,
        ),
      );
  if (!context.mounted) {
    if (result case DocumentOpened(:final bytes)) {
      bytes.fillRange(0, bytes.length, 0);
    }
    return;
  }
  switch (result) {
    case DocumentOpenCancelled():
      return;
    case DocumentTooLarge():
      show(l10n.loginImportTooLarge);
    case DocumentOpenFailed():
      show(l10n.loginImportUnknown);
    case DocumentOpened(:final bytes):
      final LoginExport export;
      try {
        export = LoginExportReader.read(bytes);
      } on EncryptedBitwardenExportException {
        show(l10n.loginImportEncrypted);
        return;
      } on UnknownLoginExportException {
        show(l10n.loginImportUnknown);
        return;
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      await context.push(AppRoutes.loginImport, extra: export);
  }
}

/// Dosyadan okunan girişleri gösterir; kullanıcı seçtiklerini ekler. Hiçbir
/// şey onaydan önce kaydedilmez.
///
/// Kasada zaten olan kayıtlar seçilmemiş gelir ama istenirse seçilebilir.
class LoginImportScreen extends ConsumerStatefulWidget {
  const new({required this.export, super.key});

  final LoginExport export;

  @override
  ConsumerState<LoginImportScreen> createState() => _LoginImportScreenState();
}

class _LoginImportScreenState extends ConsumerState<LoginImportScreen> {
  LoginImportPlan? _plan;
  Set<int> _selected = {};
  bool _saving = false;

  Future<void> _save(LoginImportPlan plan) async {
    if (_saving || _selected.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final chosen = [
        for (final index in _selected.toList()..sort()) plan.candidates[index],
      ];
      final items = await ref.read(loginsControllerProvider.notifier).addAll([
        for (final candidate in chosen) candidate.content,
      ]);
      // 2FA hesapları eklenen kayıtlara bağlanır.
      final otps = <OtpContent>[
        for (final (index, candidate) in chosen.indexed)
          if (candidate.otp case final otp? when !candidate.otpAlreadySaved)
            otp.copyWith(loginId: items[index].id),
      ];
      if (otps.isNotEmpty) {
        await ref.read(otpsControllerProvider.notifier).addAll(otps);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.loginImportDone(items.length))),
      );
      await _remindToDelete(l10n);
      if (mounted) context.pop();
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remindToDelete(AppLocalizations l10n) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: Text(l10n.loginImportDeleteTitle),
      content: Text(l10n.loginImportDeleteBody),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.loginImportDeleteOk),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logins = ref.watch(loginsControllerProvider);
    final otps = ref.watch(otpsControllerProvider);
    var plan = _plan;
    if (plan == null) {
      if (logins is! LoginsLoaded || otps is! OtpsLoaded) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.loginImportTitle)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      // Liste bir kez hazırlanır; kaydederken kasa değişse de seçim bozulmaz.
      plan = _plan = planLoginImport(
        widget.export,
        existingLogins: logins.items,
        existingOtps: otps.items,
      );
      _selected = {
        for (final (index, candidate) in plan.candidates.indexed)
          if (!candidate.duplicate) index,
      };
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginImportTitle)),
      body: _list(l10n, plan),
    );
  }

  Widget _list(AppLocalizations l10n, LoginImportPlan plan) {
    final hasDuplicates = plan.candidates.any((c) => c.duplicate);
    return Column(
      children: [
        _Notice(
          icon: Icons.description_outlined,
          text: l10n.loginImportRead(
            plan.candidates.length,
            _sourceName(plan.source),
          ),
        ),
        if (plan.skipped > 0)
          _Notice(
            icon: Icons.info_outline,
            text: l10n.loginImportSkipped(plan.skipped),
          ),
        if (plan.skippedOtps > 0)
          _Notice(
            icon: Icons.info_outline,
            text: l10n.loginImportSkippedOtps(plan.skippedOtps),
          ),
        if (hasDuplicates)
          _Notice(
            icon: Icons.content_copy_outlined,
            text: l10n.loginImportDuplicatesNote,
          ),
        Expanded(
          child: plan.candidates.isEmpty
              ? Center(child: Text(l10n.loginImportNothing))
              : ListView.builder(
                  itemCount: plan.candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = plan.candidates[index];
                    final content = candidate.content;
                    final subtitle = [
                      if (content.username.isNotEmpty) content.username,
                      if (content.urls.isNotEmpty) _hostOf(content.urls.first),
                      if (candidate.otp != null && !candidate.otpAlreadySaved)
                        l10n.loginImportWithOtp,
                      if (candidate.duplicate) l10n.loginImportDuplicate,
                    ].where((part) => part.isNotEmpty).join(' · ');
                    return CheckboxListTile(
                      value: _selected.contains(index),
                      onChanged: _saving
                          ? null
                          : (checked) => setState(() {
                              if (checked ?? false) {
                                _selected.add(index);
                              } else {
                                _selected.remove(index);
                              }
                            }),
                      title: Text(content.name),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty || _saving
                    ? null
                    : () => _save(plan),
                child: Text(l10n.loginImportAdd(_selected.length)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _hostOf(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.isEmpty ? url : host;
}

String _sourceName(LoginExportSource source) => switch (source) {
  LoginExportSource.bitwardenJson => 'Bitwarden (JSON)',
  LoginExportSource.bitwardenCsv => 'Bitwarden (CSV)',
  LoginExportSource.chromeCsv => 'Chrome (CSV)',
  LoginExportSource.keepassxcCsv => 'KeePassXC (CSV)',
};

class _Notice extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: ListTile(leading: Icon(icon), title: Text(text)),
      ),
    );
  }
}
