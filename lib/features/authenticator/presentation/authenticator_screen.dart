import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keykey/app/last_saved.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_animated_items.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otp_clock.dart';
import 'package:keykey/features/authenticator/application/otp_search.dart';
import 'package:keykey/features/authenticator/application/otp_visibility.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/otp_clock_builder.dart';
import 'package:keykey/features/authenticator/presentation/otp_code_tile.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/authenticator/presentation/otp_gate.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// 2FA kodlarının listesi.
///
/// TOTP hesabı varken liste [OtpClockBuilder] ile saniyede birkaç kez
/// yenilenir. Sekme arka plandayken `go_router` `TickerMode`'u kapatır,
/// geri sayım da durur.
enum _ScreenAction { clockHelp, trash }

class AuthenticatorScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AuthenticatorScreen> createState() =>
      _AuthenticatorScreenState();
}

class _AuthenticatorScreenState extends ConsumerState<AuthenticatorScreen> {
  final _search = TextEditingController();

  /// Bu ekranda üretilmiş HOTP kodları, hesap kimliğine göre. Kasa
  /// kilitlenince ekran kapanır ve bunlar da gider.
  final Map<String, String> _hotpCodes = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTime _now() => ref.read(otpClockProvider)();

  Future<void> _copy(String code) => copySensitive(context, ref, code);

  Future<void> _generate(OtpItem item) async {
    final controller = ref.read(otpsControllerProvider.notifier);
    try {
      final code = await controller.nextHotpCode(item);
      if (mounted) setState(() => _hotpCodes[otpIdHex(item)] = code);
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on OtpNotFoundException {
      // Hesap bu sırada silindi, liste zaten güncellendi.
    }
  }

  Future<void> _onAction(OtpItem item, OtpTileAction action) async {
    final controller = ref.read(otpsControllerProvider.notifier);
    try {
      switch (action) {
        case OtpTileAction.edit:
          await context.push(AppRoutes.authenticatorItemEdit(otpIdHex(item)));
        case OtpTileAction.favorite:
          await controller.setFavorite(item, favorite: !item.content.favorite);
        case OtpTileAction.trash:
          final l10n = AppLocalizations.of(context);
          await controller.moveToTrash(item, DateTime.now().toUtc());
          if (!mounted) return;
          showKkSnack(
            context,
            l10n.loginMovedToTrash,
            action: SnackBarAction(
              label: l10n.loginUndo,
              onPressed: () => unawaited(controller.restoreById(item.id)),
            ),
          );
      }
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on OtpNotFoundException {
      // Hesap bu sırada silindi, liste zaten güncellendi.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(otpsControllerProvider);
    if (state is! OtpsLoaded) _hotpCodes.clear();

    return KkScaffold(
      appBar: kkRootAppBar(
        context,
        title: l10n.navAuthenticator,
        actions: [
          KkMenuButton<_ScreenAction>(
            tooltip: l10n.screenMore,
            onSelected: (action) => switch (action) {
              _ScreenAction.clockHelp => unawaited(
                showClockHelp(context, _now()),
              ),
              _ScreenAction.trash => unawaited(
                context.push(AppRoutes.authenticatorTrash),
              ),
            },
            items: [
              KkMenuItem(
                value: _ScreenAction.clockHelp,
                label: l10n.otpClockHelp,
                icon: Icons.schedule_rounded,
              ),
              KkMenuItem(
                value: _ScreenAction.trash,
                label: l10n.trashTitle,
                icon: Icons.delete_outline_rounded,
              ),
            ],
          ),
        ],
      ),
      body: switch (state) {
        OtpsLoading() => const Center(child: CircularProgressIndicator()),
        OtpsLoaded() => switch (ref.watch(otpCodesVisibleProvider)) {
          null => const Center(child: CircularProgressIndicator()),
          false => const OtpGate(),
          true => _loaded(context, l10n, state),
        },
      },
    );
  }

  Widget _loaded(
    BuildContext context,
    AppLocalizations l10n,
    OtpsLoaded state,
  ) {
    final visible = visibleOtps(state.items, _search.text);
    final hasAccounts = state.active.isNotEmpty;

    return Column(
      children: [
        if (hasAccounts)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SecretField(
              controller: _search,
              label: l10n.vaultSearch,
              obscure: false,
              search: true,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (state.unreadableCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: GlassSurface(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.vaultUnreadable(state.unreadableCount)),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: OtpClockBuilder(
            // TOTP yoksa saati izlemeye gerek yok, pil harcanmaz.
            active: visible.any(
              (item) => item.content.parameters.kind == OtpKind.totp,
            ),
            builder: (context, now) => KkItemsView<OtpItem>(
              items: visible,
              keyOf: otpIdHex,
              // Altta yüzen menü için boşluk.
              padding: EdgeInsets.fromLTRB(16, 4, 16, navClearance(context)),
              empty: Text(
                hasAccounts ? l10n.otpNoResults : l10n.otpEmpty,
                textAlign: TextAlign.center,
              ),
              itemBuilder: (context, item, index) {
                final loginId = item.content.loginId;
                return OtpCodeTile(
                  key: ValueKey(otpIdHex(item)),
                  item: item,
                  now: now,
                  flash: watchLastSaved(ref, savedOtpKey(otpIdHex(item))),
                  linkedLogin: loginId == null
                      ? null
                      : findLogin(
                          ref.watch(loginsControllerProvider),
                          loginIdHex(loginId),
                        )?.content,
                  hotpCode: _hotpCodes[otpIdHex(item)],
                  onCopy: _copy,
                  onGenerate: () => unawaited(_generate(item)),
                  onAction: (action) => unawaited(_onAction(item, action)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Kodlar tutmadığında saatin neden önemli olduğunu anlatır.
Future<void> showClockHelp(BuildContext context, DateTime now) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final local = now.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final time =
      '${DateFormat.yMMMd(locale).add_Hms().format(local)} '
      '(UTC$sign$hours:$minutes)';
  return showKkSheet<void>(
    context,
    builder: (context) => KkSheetContent(
      title: l10n.otpClockHelpTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.otpClose),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.otpClockHelpBody),
          const SizedBox(height: 16),
          Text(
            l10n.otpClockNow(time),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
