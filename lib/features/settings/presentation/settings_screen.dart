import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_entrance.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/app/ui/kk_switch.dart';
import 'package:keykey/app/web_page.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/presentation/confirm_identity.dart';
import 'package:keykey/features/autofill/presentation/autofill_setup_section.dart';
import 'package:keykey/features/backup/presentation/backup_section.dart';
import 'package:keykey/features/backup/presentation/backup_status_card.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/application/theme_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  BiometricSupport _support = BiometricSupport.unavailable;
  bool _biometricEnabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBiometric());
  }

  Future<void> _loadBiometric() async {
    final controller = ref.read(vaultControllerProvider.notifier);
    final support = await controller.biometricSupport();
    final enabled = await controller.isBiometricUsable();
    if (!mounted) return;
    setState(() {
      _support = support;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _setBiometric({required bool enable}) async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final controller = ref.read(vaultControllerProvider.notifier);
    setState(() => _busy = true);
    try {
      if (enable) {
        final outcome = await controller.enableBiometric(
          BiometricTexts(
            title: l10n.biometricEnableTitle,
            negativeButton: l10n.biometricCancel,
          ),
        );
        final message = switch (outcome) {
          BiometricSuccess() || BiometricCancelled() => null,
          BiometricLockedOut() => l10n.biometricEnableLockedOut,
          BiometricInvalidated() ||
          BiometricFailed() => l10n.biometricEnableFailed,
        };
        if (message != null) {
          snack(message);
        }
      } else {
        await controller.disableBiometric();
      }
    } on Exception {
      snack(l10n.biometricEnableFailed);
    } finally {
      await _loadBiometric();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Açmak serbesttir. Kapatmak kimlik doğrulaması ister, yoksa kilidi açık
  /// telefonu eline alan biri ayarı kapatıp kodları görebilirdi.
  Future<void> _setOtpRequireAuth({required bool value}) async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    if (!value && !await confirmIdentity(context, ref)) return;
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setOtpRequireAuth(value: value);
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on Exception {
      snack(l10n.loginSaveFailed);
    }
  }

  Future<void> _setAutofillCopyOtp({required bool value}) async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setAutofillCopyOtp(value: value);
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on Exception {
      snack(l10n.loginSaveFailed);
    }
  }

  static String _themeName(AppLocalizations l10n, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l10n.themeSystem,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      };

  /// Alttan açılan pencerede Sistem / Açık / Koyu; seçilmeden kapatılırsa
  /// tema değişmez.
  Future<void> _chooseTheme(ThemeMode current) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showKkSheet<ThemeMode>(
      context,
      builder: (context) {
        final accent = KkGlass.of(context).accent;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.settingsTheme,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                for (final mode in ThemeMode.values)
                  ListTile(
                    title: Text(_themeName(l10n, mode)),
                    selected: mode == current,
                    trailing: mode == current
                        ? Icon(Icons.check_rounded, color: accent)
                        : null,
                    onTap: () => Navigator.pop(context, mode),
                  ),
              ],
            ),
          ),
        );
      },
    );
    // Pencere açıkken ekran kapanmış olabilir (ör. kasa kilitlendi).
    if (!mounted || chosen == null) return;
    await ref.read(themeModeProvider.notifier).select(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final version = ref.watch(appVersionProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    return KkScaffold(
      appBar: kkRootAppBar(context, title: l10n.navSettings),
      body: KkEntranceScope(
        child: ListView(
          // Altta: yüzen menü.
          padding: EdgeInsets.only(bottom: navClearance(context)),
          children: [
            for (final (i, section) in [
              const BackupStatusCard(),
              KkSection(
                title: l10n.settingsGroupSecurity,
                children: [
                  ListTile(
                    leading: const KkIconBox(icon: Icons.password_rounded),
                    title: Text(l10n.changePasswordTitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.changePassword),
                  ),
                  if (_support == BiometricSupport.available)
                    KkSwitchTile(
                      infoTitle: l10n.settingsBiometric,
                      info: l10n.settingsBiometricHint,
                      secondary: const KkIconBox(
                        icon: Icons.fingerprint_rounded,
                      ),
                      title: Text(l10n.settingsBiometric),
                      value: _biometricEnabled,
                      onChanged: _busy
                          ? null
                          : (value) => _setBiometric(enable: value),
                    ),
                  if (_support == BiometricSupport.notEnrolled)
                    ListTile(
                      enabled: false,
                      leading: const KkIconBox(icon: Icons.fingerprint_rounded),
                      title: Text(l10n.settingsBiometric),
                      subtitle: KkRowSubtitle(
                        l10n.settingsBiometricNotEnrolled,
                      ),
                    ),
                  KkSwitchTile(
                    infoTitle: l10n.settingsOtpRequireAuth,
                    info: l10n.settingsOtpRequireAuthHelp,
                    secondary: const KkIconBox(icon: Icons.shield_rounded),
                    title: Text(l10n.settingsOtpRequireAuth),
                    value: settings?.otpRequireAuth ?? false,
                    onChanged: settings == null
                        ? null
                        : (value) => _setOtpRequireAuth(value: value),
                  ),
                  ListTile(
                    leading: const KkIconBox(icon: Icons.lock_rounded),
                    title: Text(l10n.settingsLockNow),
                    onTap: () =>
                        ref.read(vaultControllerProvider.notifier).lock(),
                  ),
                ],
              ),
              const BackupSection(),
              AutofillSetupSection(
                children: [
                  KkSwitchTile(
                    infoTitle: l10n.settingsAutofillCopyOtp,
                    info: l10n.settingsAutofillCopyOtpHelp(
                      SensitiveClipboard.clearAfter.inSeconds,
                    ),
                    secondary: const KkIconBox(
                      icon: Icons.content_paste_go_rounded,
                    ),
                    title: Text(l10n.settingsAutofillCopyOtp),
                    value: settings?.autofillCopyOtp ?? false,
                    onChanged: settings == null
                        ? null
                        : (value) =>
                              unawaited(_setAutofillCopyOtp(value: value)),
                  ),
                ],
              ),
              KkSection(
                title: l10n.settingsGroupAppearance,
                children: [
                  ListTile(
                    leading: const KkIconBox(icon: Icons.contrast_rounded),
                    title: Text(l10n.settingsTheme),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_themeName(l10n, themeMode)),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => unawaited(_chooseTheme(themeMode)),
                  ),
                ],
              ),
              KkSection(
                title: l10n.settingsGroupAbout,
                children: [
                  ListTile(
                    leading: const KkIconBox(icon: Icons.info_rounded),
                    title: Text(l10n.settingsVersion),
                    trailing: Text(version ?? ''),
                  ),
                  ListTile(
                    leading: const KkIconBox(icon: Icons.auto_stories_rounded),
                    title: Text(l10n.settingsShowIntro),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.intro),
                  ),
                  ListTile(
                    leading: const KkIconBox(icon: Icons.code_rounded),
                    title: Text(l10n.aboutSource),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => unawaited(
                      openWebPage(context, ref, Uri.parse(keyKeyRepository)),
                    ),
                  ),
                  ListTile(
                    leading: const KkIconBox(icon: Icons.bug_report_rounded),
                    title: Text(l10n.aboutIssues),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => unawaited(
                      openWebPage(
                        context,
                        ref,
                        Uri.parse('$keyKeyRepository/issues'),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const KkIconBox(icon: Icons.privacy_tip_rounded),
                    title: Text(l10n.aboutPrivacy),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => unawaited(
                      openWebPage(context, ref, _privacyPage(context)),
                    ),
                  ),
                  ListTile(
                    leading: const KkIconBox(icon: Icons.description_rounded),
                    title: Text(l10n.settingsLicenses),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.licenses),
                  ),
                ],
              ),
            ].indexed)
              KkEntrance(index: i, child: section),
          ],
        ),
      ),
    );
  }
}

/// Gizlilik bildirimi arayüz dilinde; Türkçe dışında İngilizcesi.
Uri _privacyPage(BuildContext context) {
  final file = Localizations.localeOf(context).languageCode == 'tr'
      ? 'gizlilik.md'
      : 'privacy.md';
  return Uri.parse('$keyKeyRepository/blob/main/resources/docs/$file');
}
