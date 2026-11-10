import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/record_watermark.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/features/authenticator/application/otp_clock.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/application/autofill_matches.dart';
import 'package:keykey/features/autofill/application/autofill_otp.dart';
import 'package:keykey/features/autofill/domain/fill_warnings.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/autofill/presentation/autofill_app.dart';
import 'package:keykey/features/autofill/presentation/autofill_sheet_frame.dart';
import 'package:keykey/features/autofill/presentation/fill_confirm.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kasa açıldıktan sonra doldurulacak kaydın seçildiği ekran.
///
/// Eşleşen kayıtlar üstte, diğerleri altta. Arama bütün kayıtlarda yapılır.
class AutofillPickScreen extends ConsumerStatefulWidget {
  const new({required this.target, super.key});

  final AutofillTarget target;

  @override
  ConsumerState<AutofillPickScreen> createState() => _AutofillPickScreenState();
}

class _AutofillPickScreenState extends ConsumerState<AutofillPickScreen> {
  final _query = TextEditingController();
  bool _busy = false;

  /// Doğrudan doldurma bir kez denenir; eşleşmeler yeniden hesaplanınca
  /// ikinci kez doldurulmaz.
  bool _directChecked = false;

  /// Tek kesin eşleşme dolduruluyor; liste gösterilmez.
  bool _directFilling = false;

  /// Arama kutusu odakta: pencere uzar, bütün kayıtlar aranır.
  bool _searchFocused = false;

  /// Gösterilen uyarı; varken liste yerine bu çizilir.
  Widget? _confirming;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      autofillMatchesProvider,
      (_, next) => _maybeFillDirectly(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Tek bir kesin eşleşme varsa ve hiçbir uyarı yoksa seçme penceresi
  /// açılmadan doldurur. Kural güvenlik tasarımı belgesinin "Akış"
  /// bölümünde.
  void _maybeFillDirectly(AsyncValue<LoginMatches> next) {
    if (_directChecked || next.isLoading) return;
    if (next case AsyncData(:final value)) {
      // Kayıtlar yüklenmeden hesaplanan eşleşme boştur; beklenir.
      if (ref.read(loginsControllerProvider) is! LoginsLoaded) return;
      _directChecked = true;
      final item = directFillCandidate(target: widget.target, matches: value);
      if (item == null || _busy) return;
      _busy = true;
      setState(() => _directFilling = true);
      unawaited(_fill(item).whenComplete(() => _busy = false));
    } else if (next is AsyncError) {
      _directChecked = true;
    }
  }

  /// Şüpheli bir durum varsa önce uyarır ve onay ister, istenirse uygulamayı
  /// kayda bağlar, sonra doldurur.
  Future<void> _pick(LoginItem item, LoginMatches matches) async {
    if (_busy) return;
    _busy = true;
    try {
      final target = widget.target;
      final warnings = fillWarnings(
        target: target,
        item: item,
        matches: matches,
      );
      var chosen = item;
      if (warnings.isNotEmpty) {
        final answer = await _confirm(item, warnings);
        if (answer == null || !mounted) return;
        if (answer.bind && canBindApp(target: target, warnings: warnings)) {
          chosen = await _bindApp(item);
        }
      }
      await _fill(chosen);
    } finally {
      _busy = false;
    }
  }

  /// Uyarıları listenin yerinde, aynı pencerede gösterir. Vazgeçilirse
  /// `null`, onaylanırsa uygulamanın kayda bağlanıp bağlanmayacağı.
  Future<({bool bind})?> _confirm(LoginItem item, Set<FillWarning> warnings) {
    final completer = Completer<({bool bind})?>();
    void finish(({bool bind})? answer) {
      if (mounted) setState(() => _confirming = null);
      if (!completer.isCompleted) completer.complete(answer);
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(
      () => _confirming = FillConfirmContent(
        target: widget.target,
        item: item,
        warnings: warnings,
        onCancel: () => finish(null),
        onConfirm: ({required bind}) => finish((bind: bind)),
      ),
    );
    return completer.future;
  }

  /// Uygulamayı paket adı ve imza özetleriyle kayda ekler.
  Future<LoginItem> _bindApp(LoginItem item) {
    final target = widget.target;
    final app = LoginApp(
      packageName: target.packageName,
      certsSha256: target.certsSha256,
    );
    final apps = [
      for (final existing in item.content.apps)
        if (existing.packageName != app.packageName) existing,
      app,
    ];
    return ref
        .read(loginsControllerProvider.notifier)
        .update(item, item.content.copyWith(apps: apps));
  }

  /// Değerleri alır, kasayı kilitler ve forma verir. Kilit önce gelir:
  /// anahtarlar silindikten sonra yalnızca seçilen iki değer ve varsa 2FA
  /// kodu kalır. Kod, ekran kapanmadan önce panoya kopyalanır.
  Future<void> _fill(LoginItem item) async {
    final l10n = AppLocalizations.of(context);
    final name = item.content.name.trim();
    final notice = name.isEmpty
        ? l10n.autofillFilledNoticeUnnamed
        : l10n.autofillFilledNotice(name);
    final username = item.content.username;
    final password = item.content.password;
    // markDone ekranı bir sonraki karede kapatır; kapanmış ekranda `ref`
    // kullanılamaz. Sonradan gerekenler beklemeden önce alınır.
    final done = ref.read(autofillDoneProvider.notifier);
    final vault = ref.read(vaultControllerProvider.notifier);
    final clipboard = ref.read(sensitiveClipboardProvider);
    final bridge = ref.read(autofillBridgeProvider);
    final code = await _linkedOtpCode(item);
    done.markDone();
    vault.lock();
    if (code != null) {
      try {
        await clipboard.copy(code);
      } on Exception {
        // Kopyalanamazsa doldurma yine yapılır.
      }
    }
    await bridge.fill(username: username, password: password, notice: notice);
  }

  /// Ayar açıksa kayda bağlı TOTP hesabının güncel kodu. Hata doldurmayı
  /// engellemez.
  Future<String?> _linkedOtpCode(LoginItem item) async {
    final status = ref.read(vaultControllerProvider);
    if (status is! VaultOpen) return null;
    try {
      return await linkedOtpCodeForFill(
        settings: ref.read(settingsRepositoryFactoryProvider)(status.session),
        otps: ref.read(otpRepositoryFactoryProvider)(status.session),
        loginId: item.id,
        now: ref.read(otpClockProvider)(),
      );
    } on Exception {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    final matches = switch (ref.watch(autofillMatchesProvider)) {
      AsyncData(:final value) => value,
      // Eşleştirme başarısız olursa bütün kayıtlar eşleşmesiz gösterilir.
      AsyncError() => LoginMatches.empty,
      _ => null,
    };
    void cancel() => unawaited(ref.read(autofillBridgeProvider).cancel());
    final confirming = _confirming;
    final ready = !_directFilling && state is LoginsLoaded && matches != null;
    // Eşleşme yoksa ya da aranıyorsa bütün kayıtlar gösterilir; pencere uzar.
    final expanded =
        ready &&
        confirming == null &&
        (_searchFocused ||
            _query.text.trim().isNotEmpty ||
            matches.matches.isEmpty);
    return AutofillSheetFrame(
      onDismiss: cancel,
      expanded: expanded,
      child: switch (confirming) {
        final Widget confirm => confirm,
        null when ready => _picker(context, l10n, state, matches, cancel),
        null => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }

  Widget _picker(
    BuildContext context,
    AppLocalizations l10n,
    LoginsLoaded state,
    LoginMatches matches,
    VoidCallback cancel,
  ) {
    final query = _query.text.trim();
    final searching = query.isNotEmpty;
    final showAll = _searchFocused || searching || matches.matches.isEmpty;
    final filtered = filterLogins(
      state.indexed,
      LoginFilter(query: _query.text),
    );
    final matched = [for (final m in matches.matches) m.item];
    final matchedIds = {for (final item in matched) _key(item)};
    final hits = {for (final item in filtered) _key(item)};
    // Aramada eşleşenler yine önce gelir, ama yalnızca aramaya uyanlar.
    final top = [
      for (final item in matched)
        if (!searching || hits.contains(_key(item))) item,
    ];
    final rest = showAll
        ? [
            for (final item in filtered)
              if (!matchedIds.contains(_key(item))) item,
          ]
        : const <LoginItem>[];
    final targetName = autofillTargetName(widget.target);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutofillSheetHeader(
          title: l10n.autofillFor(targetName),
          onClose: cancel,
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (state.items.isEmpty)
                _note(l10n.autofillEmpty)
              else if (top.isEmpty && rest.isEmpty)
                _note(l10n.vaultNoResults)
              else ...[
                if (!searching && matched.isEmpty)
                  _note(l10n.autofillNoMatch(targetName)),
                if (top.isNotEmpty) ...[
                  if (showAll) _header(context, l10n.autofillMatching),
                  for (final item in top) _tile(item, matches),
                ],
                if (rest.isNotEmpty) ...[
                  _header(
                    context,
                    top.isEmpty
                        ? l10n.autofillAllLogins
                        : l10n.autofillOtherLogins,
                  ),
                  for (final item in rest) _tile(item, matches),
                ],
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Focus(
            onFocusChange: (focused) =>
                setState(() => _searchFocused = focused),
            child: SecretField(
              controller: _query,
              label: l10n.autofillSearchOther,
              obscure: false,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }

  static String _key(LoginItem item) => item.id.join(',');

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    child: Text(text, textAlign: TextAlign.center),
  );

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );

  Widget _tile(LoginItem item, LoginMatches matches) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: KkCard(
      title: Text(item.content.name.isEmpty ? '—' : item.content.name),
      subtitle: item.content.username.isEmpty
          ? null
          : Text(item.content.username),
      watermark: RecordWatermark(login: item.content),
      onTap: () => unawaited(_pick(item, matches)),
    ),
  );
}
