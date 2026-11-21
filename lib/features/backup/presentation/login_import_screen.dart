import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/backup/application/login_import_plan.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/presentation/vault_entry_tiles.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Belge seçiciyle bir parola dışa aktarması seçtirir, okur ve içe aktarma
/// ekranını açar. Dosyanın baytları okunduktan sonra sıfırlanır.
Future<void> pickLoginExport(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final show = kkSnackFor(context);

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
        export = LoginExportReader.read(
          bytes,
          labels: ImportLabels(
            cardNumber: l10n.importLabelCardNumber,
            expiry: l10n.importLabelExpiry,
            securityCode: l10n.importLabelSecurityCode,
          ),
        );
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

/// Dosyadan okunan parola, kart ve notları gösterir; kullanıcı seçtiklerini
/// ekler. Hiçbir şey onaydan önce kaydedilmez.
///
/// Kasada zaten olan kayıtlar seçilmemiş gelir ama istenirse seçilebilir.
class LoginImportScreen extends ConsumerStatefulWidget {
  const new({required this.export, super.key});

  final LoginExport export;

  @override
  ConsumerState<LoginImportScreen> createState() => _LoginImportScreenState();
}

/// Listedeki satırın sırası: önce parolalar, sonra kartlar, sonra notlar.
/// Seçim bu sıradaki konumu tutar.
class _LoginImportScreenState extends ConsumerState<LoginImportScreen> {
  LoginImportPlan? _plan;
  Set<int> _selected = {};
  bool _saving = false;

  List<T> _chosen<T>(List<T> items, int offset) => [
    for (final (index, item) in items.indexed)
      if (_selected.contains(offset + index)) item,
  ];

  Future<void> _save(LoginImportPlan plan) async {
    if (_saving || _selected.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    setState(() => _saving = true);
    try {
      final chosen = _chosen(plan.candidates, 0);
      final cards = _chosen(plan.cards, plan.candidates.length);
      final notes = _chosen(
        plan.notes,
        plan.candidates.length + plan.cards.length,
      );
      final items = chosen.isEmpty
          ? const <LoginItem>[]
          : await ref.read(loginsControllerProvider.notifier).addAll([
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
      if (cards.isNotEmpty) {
        await ref.read(cardsControllerProvider.notifier).addAll([
          for (final card in cards) card.content,
        ]);
      }
      if (notes.isNotEmpty) {
        await ref.read(notesControllerProvider.notifier).addAll([
          for (final note in notes) note.content,
        ]);
      }
      if (!mounted) return;
      // Kayıt bitti; hatırlatma açıkken düğmede ilerleme halkası dönmesin.
      setState(() => _saving = false);
      snack(l10n.loginImportDone(items.length + cards.length + notes.length));
      await _remindToDelete(l10n);
      if (mounted) context.pop();
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remindToDelete(AppLocalizations l10n) => showKkSheet<void>(
    context,
    builder: (context) => KkSheetContent(
      title: l10n.loginImportDeleteTitle,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.loginImportDeleteOk),
        ),
      ],
      child: Text(l10n.loginImportDeleteBody),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logins = ref.watch(loginsControllerProvider);
    final otps = ref.watch(otpsControllerProvider);
    final cards = ref.watch(cardsControllerProvider);
    final notes = ref.watch(notesControllerProvider);
    var plan = _plan;
    if (plan == null) {
      if (logins is! LoginsLoaded ||
          otps is! OtpsLoaded ||
          cards is! RecordsLoaded<CardContent> ||
          notes is! RecordsLoaded<NoteContent>) {
        return KkScaffold(
          appBar: kkAppBar(context, title: l10n.loginImportTitle),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      // Liste bir kez hazırlanır; kaydederken kasa değişse de seçim bozulmaz.
      plan = _plan = planLoginImport(
        widget.export,
        existingLogins: logins.items,
        existingOtps: otps.items,
        existingCards: cards.items,
        existingNotes: notes.items,
      );
      final duplicates = [
        for (final candidate in plan.candidates) candidate.duplicate,
        for (final candidate in plan.cards) candidate.duplicate,
        for (final candidate in plan.notes) candidate.duplicate,
      ];
      _selected = {
        for (final (index, duplicate) in duplicates.indexed)
          if (!duplicate) index,
      };
    }
    final ready = plan;
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.loginImportTitle),
      body: _list(l10n, ready),
      bottomNavigationBar: KkBottomAction(
        label: l10n.loginImportAdd(_selected.length),
        busy: _saving,
        onPressed: _selected.isEmpty ? null : () => _save(ready),
      ),
    );
  }

  List<_Row> _rows(AppLocalizations l10n, LoginImportPlan plan) {
    final now = DateTime.now();
    String join(List<String> parts) =>
        parts.where((part) => part.isNotEmpty).join(' · ');
    return [
      for (final candidate in plan.candidates)
        _Row(
          icon: Icons.key_rounded,
          title: candidate.content.name,
          subtitle: join([
            candidate.content.username,
            if (candidate.content.urls.isNotEmpty)
              _hostOf(candidate.content.urls.first),
            if (candidate.otp != null && !candidate.otpAlreadySaved)
              l10n.loginImportWithOtp,
            if (candidate.duplicate) l10n.loginImportDuplicate,
          ]),
        ),
      for (final candidate in plan.cards)
        _Row(
          icon: Icons.credit_card_rounded,
          title: cardTitle(candidate.content),
          subtitle: join([
            cardSummary(l10n, candidate.content, now),
            if (candidate.adjusted) l10n.importCardAdjusted,
            if (candidate.duplicate) l10n.loginImportDuplicate,
          ]),
        ),
      for (final candidate in plan.notes)
        _Row(
          icon: Icons.sticky_note_2_outlined,
          title: candidate.content.name.trim().isEmpty
              ? '—'
              : candidate.content.name,
          subtitle: join([if (candidate.duplicate) l10n.loginImportDuplicate]),
        ),
    ];
  }

  Widget _list(AppLocalizations l10n, LoginImportPlan plan) {
    final rows = _rows(l10n, plan);
    final hasDuplicates =
        plan.candidates.any((c) => c.duplicate) ||
        plan.cards.any((c) => c.duplicate) ||
        plan.notes.any((c) => c.duplicate);
    final notices = [
      _Notice(
        icon: Icons.description_outlined,
        text: l10n.loginImportRead(plan.total, _sourceName(plan.source)),
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
    ];
    // Bilgi kartları listeyle birlikte kayar; büyük yazıda listeye yer kalsın.
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverList.list(children: notices),
              if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l10n.loginImportNothing)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  sliver: SliverList.separated(
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return GlassSurface(
                        child: CheckboxListTile(
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
                          secondary: Icon(
                            row.icon,
                            color: KkGlass.of(context).accent,
                          ),
                          title: Text(row.title),
                          subtitle: row.subtitle.isEmpty
                              ? null
                              : Text(row.subtitle),
                        ),
                      );
                    },
                  ),
                ),
            ],
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
  LoginExportSource.firefoxCsv => 'Firefox (CSV)',
  LoginExportSource.keepassxcCsv => 'KeePassXC (CSV)',
};

/// Önizleme listesinin bir satırı.
final class _Row {
  const new({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;
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
