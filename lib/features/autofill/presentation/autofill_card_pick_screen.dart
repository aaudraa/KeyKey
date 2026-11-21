import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/record_avatar.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/presentation/autofill_app.dart';
import 'package:keykey/features/autofill/presentation/autofill_sheet_frame.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/application/vault_entries.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:keykey/features/vault/presentation/vault_entry_tiles.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ödeme formuna doldurulacak kartın seçildiği ekran.
///
/// Kart bir siteye ya da uygulamaya bağlı olmadığı için eşleştirme yok:
/// çöp kutusunda olmayan bütün kartlar listelenir ve kart her zaman
/// listeden seçilir. Başlık kartın nereye gideceğini söyler. Kurallar
/// `resources/docs/kart-doldurma.md` belgesinde.
class AutofillCardPickScreen extends ConsumerStatefulWidget {
  const new({required this.target, super.key});

  final AutofillTarget target;

  @override
  ConsumerState<AutofillCardPickScreen> createState() =>
      _AutofillCardPickScreenState();
}

class _AutofillCardPickScreenState
    extends ConsumerState<AutofillCardPickScreen> {
  final _query = TextEditingController();
  bool _busy = false;

  /// Arama kutusu odakta: pencere uzar.
  bool _searchFocused = false;

  /// Şifresiz bağlantı uyarısı gösterilen kart; varken liste yerine uyarı
  /// çizilir.
  CardItem? _confirming;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Sayfa güvenilen bir tarayıcıda `http` ile açılmış.
  bool get _insecure =>
      widget.target.isWeb && widget.target.webScheme?.toLowerCase() == 'http';

  void _pick(CardItem item) {
    if (_busy) return;
    if (_insecure) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _confirming = item);
      return;
    }
    unawaited(_fill(item));
  }

  /// Değerleri alır, kasayı kilitler ve forma verir. Kilit önce gelir:
  /// anahtarlar silindikten sonra yalnızca seçilen kartın değerleri kalır.
  Future<void> _fill(CardItem item) async {
    if (_busy) return;
    _busy = true;
    try {
      final l10n = AppLocalizations.of(context);
      final name = item.content.displayName;
      final notice = name.isEmpty
          ? l10n.autofillCardFilledUnnamed
          : l10n.autofillFilledNotice(name);
      final card = AutofillCard.of(item.content);
      // markDone ekranı bir sonraki karede kapatır; kapanmış ekranda `ref`
      // kullanılamaz. Gerekenler önceden alınır.
      final bridge = ref.read(autofillBridgeProvider);
      ref.read(autofillDoneProvider.notifier).markDone();
      ref.read(vaultControllerProvider.notifier).lock();
      await bridge.fillCard(card: card, notice: notice);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(cardsControllerProvider);
    void cancel() => unawaited(ref.read(autofillBridgeProvider).cancel());
    final confirming = _confirming;
    final ready = state is RecordsLoaded<CardContent>;
    final expanded =
        ready &&
        confirming == null &&
        (_searchFocused || _query.text.trim().isNotEmpty);
    // Uyarı açıkken geri tuşu yalnızca uyarıyı kapatır, listeye döner;
    // listedeyken pencere kapanır ve hiçbir şey doldurulmaz.
    return PopScope(
      canPop: confirming == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _confirming = null);
      },
      child: AutofillSheetFrame(
        onDismiss: cancel,
        expanded: expanded,
        child: switch (state) {
          _ when confirming != null => _InsecureCardConfirm(
            item: confirming,
            onCancel: () => setState(() => _confirming = null),
            onConfirm: () => unawaited(_fill(confirming)),
          ),
          RecordsLoaded<CardContent>(:final items) => _picker(
            context,
            l10n,
            items,
            cancel,
          ),
          _ => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ),
    );
  }

  Widget _picker(
    BuildContext context,
    AppLocalizations l10n,
    List<CardItem> items,
    VoidCallback cancel,
  ) {
    // Arama ve sıralama kasa listesiyle aynı; numaraya ve güvenlik koduna
    // bakılmaz.
    final cards = [
      for (final entry in filterEntries([
        for (final item in items) IndexedEntry(CardEntry(item)),
      ], LoginFilter(query: _query.text)))
        if (entry case CardEntry(:final item)) item,
    ];
    final hasCards = items.any((item) => !item.content.isTrashed);
    final now = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutofillSheetHeader(
          title: l10n.autofillCardFor(autofillTargetName(widget.target)),
          onClose: cancel,
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (!hasCards)
                _note(l10n.autofillCardEmpty)
              else if (cards.isEmpty)
                _note(l10n.vaultNoResults)
              else
                for (final item in cards) _tile(l10n, item, now),
            ],
          ),
        ),
        if (hasCards)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Focus(
              onFocusChange: (focused) =>
                  setState(() => _searchFocused = focused),
              child: GlassSurface(
                padding: const EdgeInsets.all(4),
                child: SecretField(
                  controller: _query,
                  label: l10n.autofillCardSearch,
                  obscure: false,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 16),
      ],
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    child: Text(text, textAlign: TextAlign.center),
  );

  Widget _tile(AppLocalizations l10n, CardItem item, DateTime now) {
    final content = item.content;
    final summary = cardSummary(l10n, content, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KkCard(
        title: Text(cardTitle(content)),
        subtitle: summary.isEmpty ? null : Text(summary),
        leading: RecordAvatar(
          login: null,
          name: content.name,
          icon: Icons.credit_card_rounded,
        ),
        onTap: () => _pick(item),
      ),
    );
  }
}

/// Şifresiz (`http`) sayfaya kart doldurmadan önceki uyarı. Listenin
/// yerinde, aynı pencerede gösterilir.
class _InsecureCardConfirm extends StatelessWidget {
  const new({
    required this.item,
    required this.onCancel,
    required this.onConfirm,
  });

  final CardItem item;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.autofillWarnTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.autofillWarnInsecureCard),
              const SizedBox(height: 12),
              Text(
                l10n.autofillWarnCard(cardTitle(item.content)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(onPressed: onCancel, child: Text(l10n.autofillCancel)),
              FilledButton(
                onPressed: onConfirm,
                child: Text(l10n.autofillFillAnyway),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
