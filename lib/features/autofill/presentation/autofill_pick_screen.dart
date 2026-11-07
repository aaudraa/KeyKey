import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/features/authenticator/application/otp_clock.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/application/autofill_matches.dart';
import 'package:keykey/features/autofill/application/autofill_otp.dart';
import 'package:keykey/features/autofill/domain/fill_warnings.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/autofill/presentation/autofill_app.dart';
import 'package:keykey/features/autofill/presentation/fill_confirm_dialog.dart';
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

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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
        final answer = await confirmFill(
          context,
          target: target,
          item: item,
          warnings: warnings,
        );
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
    final username = item.content.username;
    final password = item.content.password;
    final code = await _linkedOtpCode(item);
    ref.read(autofillDoneProvider.notifier).markDone();
    ref.read(vaultControllerProvider.notifier).lock();
    if (code != null) {
      try {
        await ref.read(sensitiveClipboardProvider).copy(code);
      } on Exception {
        // Kopyalanamazsa doldurma yine yapılır.
      }
    }
    await ref
        .read(autofillBridgeProvider)
        .fill(username: username, password: password);
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
    final matches = ref.watch(autofillMatchesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.autofillTitle),
        leading: IconButton(
          tooltip: l10n.autofillClose,
          icon: const Icon(Icons.close),
          onPressed: () => unawaited(ref.read(autofillBridgeProvider).cancel()),
        ),
      ),
      body: switch ((state, matches)) {
        (LoginsLoaded(), AsyncData(:final value)) => _list(
          context,
          l10n,
          state as LoginsLoaded,
          value,
        ),
        // Eşleştirme başarısız olursa bütün kayıtlar eşleşmesiz gösterilir.
        (LoginsLoaded(), AsyncError()) => _list(
          context,
          l10n,
          state as LoginsLoaded,
          LoginMatches.empty,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(
    BuildContext context,
    AppLocalizations l10n,
    LoginsLoaded state,
    LoginMatches matches,
  ) {
    final searching = _query.text.trim().isNotEmpty;
    final filtered = filterLogins(
      state.indexed,
      LoginFilter(query: _query.text),
    );
    final matched = [for (final m in matches.matches) m.item];
    final matchedIds = {for (final item in matched) _key(item)};
    final List<LoginItem> top;
    final List<LoginItem> rest;
    if (searching) {
      // Aramada eşleşenler yine önce gelir, ama yalnızca aramaya uyanlar.
      final hits = {for (final item in filtered) _key(item)};
      top = [
        for (final item in matched)
          if (hits.contains(_key(item))) item,
      ];
      rest = [
        for (final item in filtered)
          if (!matchedIds.contains(_key(item))) item,
      ];
    } else {
      top = matched;
      rest = [
        for (final item in filtered)
          if (!matchedIds.contains(_key(item))) item,
      ];
    }
    final targetName = autofillTargetName(widget.target);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.autofillFor(targetName),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SecretField(
            controller: _query,
            label: l10n.vaultSearch,
            obscure: false,
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (state.items.isEmpty)
          _note(l10n.autofillEmpty)
        else if (top.isEmpty && rest.isEmpty)
          _note(l10n.vaultNoResults)
        else ...[
          if (!searching && top.isEmpty)
            _note(l10n.autofillNoMatch(targetName)),
          if (top.isNotEmpty) ...[
            _header(context, l10n.autofillMatching),
            for (final item in top) _tile(item, matches),
          ],
          if (rest.isNotEmpty) ...[
            _header(
              context,
              top.isEmpty ? l10n.autofillAllLogins : l10n.autofillOtherLogins,
            ),
            for (final item in rest) _tile(item, matches),
          ],
        ],
      ],
    );
  }

  static String _key(LoginItem item) => item.id.join(',');

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(text, textAlign: TextAlign.center),
  );

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );

  Widget _tile(LoginItem item, LoginMatches matches) => ListTile(
    leading: const Icon(Icons.key),
    title: Text(item.content.name.isEmpty ? '—' : item.content.name),
    subtitle: item.content.username.isEmpty
        ? null
        : Text(item.content.username),
    onTap: () => unawaited(_pick(item, matches)),
  );
}
