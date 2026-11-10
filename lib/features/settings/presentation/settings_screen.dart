import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/presentation/confirm_identity.dart';
import 'package:keykey/features/autofill/presentation/autofill_setup_section.dart';
import 'package:keykey/features/backup/presentation/backup_section.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
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
    final messenger = ScaffoldMessenger.of(context);
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
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      } else {
        await controller.disableBiometric();
      }
    } on Exception {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.biometricEnableFailed)),
      );
    } finally {
      await _loadBiometric();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Açmak serbesttir. Kapatmak kimlik doğrulaması ister, yoksa kilidi açık
  /// telefonu eline alan biri ayarı kapatıp kodları görebilirdi.
  Future<void> _setOtpRequireAuth({required bool value}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!value && !await confirmIdentity(context, ref)) return;
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setOtpRequireAuth(value: value);
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.loginSaveFailed)));
    }
  }

  Future<void> _setAutofillCopyOtp({required bool value}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setAutofillCopyOtp(value: value);
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.loginSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final version = ref.watch(appVersionProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        // Altta: yüzen menü.
        padding: const EdgeInsets.only(bottom: kNavClearance),
        children: [
          KkSection(
            title: l10n.settingsGroupSecurity,
            children: [
              ListTile(
                leading: const Icon(Icons.password_outlined),
                title: Text(l10n.changePasswordTitle),
                onTap: () => context.push(AppRoutes.changePassword),
              ),
              if (_support == BiometricSupport.available)
                KkInfoRow(
                  infoTitle: l10n.settingsBiometric,
                  info: l10n.settingsBiometricHint,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(l10n.settingsBiometric),
                    value: _biometricEnabled,
                    onChanged: _busy
                        ? null
                        : (value) => _setBiometric(enable: value),
                  ),
                ),
              if (_support == BiometricSupport.notEnrolled)
                ListTile(
                  enabled: false,
                  leading: const Icon(Icons.fingerprint),
                  title: Text(l10n.settingsBiometric),
                  subtitle: KkRowSubtitle(l10n.settingsBiometricNotEnrolled),
                ),
              KkInfoRow(
                infoTitle: l10n.settingsOtpRequireAuth,
                info: l10n.settingsOtpRequireAuthHelp,
                child: SwitchListTile(
                  secondary: const Icon(Icons.shield_outlined),
                  title: Text(l10n.settingsOtpRequireAuth),
                  value: settings?.otpRequireAuth ?? false,
                  onChanged: settings == null
                      ? null
                      : (value) => _setOtpRequireAuth(value: value),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(l10n.settingsLockNow),
                onTap: () => ref.read(vaultControllerProvider.notifier).lock(),
              ),
            ],
          ),
          const BackupSection(),
          AutofillSetupSection(
            children: [
              KkInfoRow(
                infoTitle: l10n.settingsAutofillCopyOtp,
                info: l10n.settingsAutofillCopyOtpHelp(
                  SensitiveClipboard.clearAfter.inSeconds,
                ),
                child: SwitchListTile(
                  secondary: const Icon(Icons.content_paste_go),
                  title: Text(l10n.settingsAutofillCopyOtp),
                  value: settings?.autofillCopyOtp ?? false,
                  onChanged: settings == null
                      ? null
                      : (value) => unawaited(_setAutofillCopyOtp(value: value)),
                ),
              ),
            ],
          ),
          KkSection(
            title: l10n.settingsGroupAbout,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.settingsVersion),
                trailing: Text(version ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.settingsLicenses),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'KeyKey',
                  applicationVersion: version,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
