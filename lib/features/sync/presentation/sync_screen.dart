import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/auto_backup_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/sync/application/sync_controller.dart';
import 'package:keykey/features/sync/application/sync_merger.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:keykey/features/sync/presentation/sync_devices.dart';
import 'package:keykey/features/sync/presentation/sync_setup_form.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// "3 dakika önce" gibi göreli zaman.
String syncAgo(AppLocalizations l10n, DateTime at, DateTime now) {
  final passed = now.difference(at);
  if (passed.inMinutes < 1) return l10n.syncJustNow;
  if (passed.inHours < 1) return l10n.syncMinutesAgo(passed.inMinutes);
  if (passed.inDays < 1) return l10n.syncHoursAgo(passed.inHours);
  return l10n.syncDaysAgo(passed.inDays);
}

/// Taşıyıcı hatasının kullanıcıya söylenişi.
String syncFailureText(AppLocalizations l10n, SyncFailureKind kind) =>
    switch (kind) {
      SyncFailureKind.offline => l10n.syncErrorOffline,
      SyncFailureKind.unauthorized => l10n.syncErrorUnauthorized,
      SyncFailureKind.certificate => l10n.syncErrorCertificate,
      SyncFailureKind.redirect => l10n.syncErrorRedirect,
      SyncFailureKind.notFound => l10n.syncErrorNotFound,
      SyncFailureKind.server => l10n.syncErrorServer,
      SyncFailureKind.insufficientStorage => l10n.syncErrorStorage,
      SyncFailureKind.tooLarge => l10n.syncErrorTooLarge,
      SyncFailureKind.badResponse => l10n.syncErrorBadResponse,
    };

/// Durumun hata metni; hata yoksa `null`.
String? syncStatusError(AppLocalizations l10n, SyncStatus status) {
  if (status.otherVault) return l10n.syncOtherVaultTitle;
  final failure = status.failure;
  return failure == null ? null : syncFailureText(l10n, failure);
}

/// Bir eşitleme sorununun metni. Telefon, modeli biliniyorsa modeliyle
/// anılır. Bir kez gösterilen bildirimler (parola, kurtarma) burada yok.
String? syncIssueText(
  AppLocalizations l10n,
  SyncIssue issue,
  List<SyncDevice> devices,
) {
  String name(String device) =>
      devices.where((d) => d.device == device).firstOrNull?.name ?? device;
  return switch (issue) {
    ClockAhead(:final device) => l10n.syncIssueClock(name(device)),
    UnreadableDevice(:final device) ||
    TypeConflict(:final device) => l10n.syncIssueUnreadable(name(device)),
    NewerApp(:final device) => l10n.syncIssueNewer(name(device)),
    SlotsDiffer(:final device) => l10n.syncIssueSlots(name(device)),
    PasswordAdopted() || RecoveryAdopted() => null,
  };
}

/// Bir kez gösterilecek bildirimin metni.
String? syncNoticeText(AppLocalizations l10n, SyncIssue notice) =>
    switch (notice) {
      PasswordAdopted() => l10n.syncNoticePassword,
      RecoveryAdopted() => l10n.syncNoticeRecovery,
      _ => null,
    };

/// Ayarlardaki senkron grubu: tek satır, senkron ekranına götürür.
class SyncSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final status = ref.watch(syncControllerProvider);
    final sync = settings?.sync;
    final error = syncStatusError(l10n, status);
    final Widget subtitle;
    if (sync == null) {
      subtitle = KkRowSubtitle(l10n.syncRowOff);
    } else if (error != null) {
      subtitle = Text(error, style: TextStyle(color: theme.colorScheme.error));
    } else {
      final last = status.lastSyncAt ?? sync.lastSyncAt;
      subtitle = KkRowSubtitle(
        last == null
            ? l10n.syncRowNever
            : l10n.syncRowLast(
                syncAgo(l10n, last, ref.read(syncClockProvider)()),
              ),
      );
    }
    return KkSection(
      title: l10n.settingsGroupSync,
      children: [
        ListTile(
          leading: const KkIconBox(icon: Icons.cloud_sync_rounded),
          title: Text(l10n.syncTitle),
          subtitle: subtitle,
          trailing: const Icon(Icons.chevron_right_rounded),
          enabled: settings != null,
          onTap: () => context.push(AppRoutes.sync),
        ),
      ],
    );
  }
}

/// Ayarlar → Senkron. Kapalıyken kurulum formu, açıkken durum ve cihazlar.
class SyncScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    if (settings == null) {
      return KkScaffold(
        appBar: kkAppBar(context, title: l10n.syncTitle),
        body: const SizedBox.shrink(),
      );
    }
    if (settings.sync == null) return const SyncSetupForm();
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.syncTitle),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: const [_StatusSection(), SyncDevices(), _TurnOffSection()],
      ),
    );
  }
}

class _StatusSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(syncControllerProvider);
    final last =
        status.lastSyncAt ??
        ref.watch(settingsControllerProvider)?.sync?.lastSyncAt;
    final error = syncStatusError(l10n, status);
    final issues = [
      for (final issue in status.issues)
        ?syncIssueText(l10n, issue, status.devices),
    ];
    return KkSection(
      title: l10n.syncTitle,
      children: [
        ListTile(
          leading: const KkIconBox(icon: Icons.cloud_done_rounded),
          title: Text(l10n.syncLastSync),
          subtitle: KkRowSubtitle(
            status.running
                ? l10n.syncRunning
                : last == null
                ? l10n.syncNever
                : syncAgo(l10n, last, ref.read(syncClockProvider)()),
          ),
          trailing: Text(l10n.syncStatusOn),
        ),
        for (final text in [?error, ...issues])
          ListTile(
            leading: Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
            ),
            title: Text(text, style: TextStyle(color: theme.colorScheme.error)),
          ),
        ListTile(
          leading: const KkIconBox(icon: Icons.sync_rounded),
          title: Text(l10n.syncNow),
          enabled: !status.running,
          onTap: () => unawaited(_syncNow(context, ref)),
        ),
      ],
    );
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final status = await ref.read(syncControllerProvider.notifier).syncNow();
    if (!status.enabled) return;
    snack(syncStatusError(l10n, status) ?? l10n.syncDone);
  }
}

class _TurnOffSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
        icon: const Icon(Icons.cloud_off_rounded),
        label: Text(l10n.syncTurnOff),
        onPressed: () => unawaited(_turnOff(context, ref)),
      ),
    );
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final deleteFile = await _confirmTurnOff(context);
    if (deleteFile == null) return;
    final sync = ref.read(settingsControllerProvider)?.sync;
    if (sync == null) return;
    var deleted = true;
    if (deleteFile) {
      try {
        await ref
            .read(syncServiceProvider)
            .removeDevice(sync, ref.read(autoBackupDeviceProvider));
      } on Exception {
        deleted = false;
      }
    }
    try {
      await ref.read(settingsControllerProvider.notifier).setSync(null);
    } on VaultLockedException {
      return;
    }
    snack(deleted ? l10n.syncDisabled : l10n.syncDeleteFailed);
  }
}

/// Kapatma penceresi: onaylanırsa dosyanın da silinip silinmeyeceği,
/// vazgeçilirse `null`.
Future<bool?> _confirmTurnOff(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  var deleteFile = true;
  return showKkSheet<bool>(
    context,
    builder: (context) {
      final theme = Theme.of(context);
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.syncTurnOffTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.syncTurnOffBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: deleteFile,
                title: Text(l10n.syncTurnOffDeleteFile),
                onChanged: (value) =>
                    setState(() => deleteFile = value ?? false),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: kkDangerButtonStyle(theme.colorScheme),
                onPressed: () => Navigator.of(context).pop(deleteFile),
                child: Text(l10n.syncTurnOffConfirm),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.syncCancel),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bilgi penceresi: tek "Tamam" düğmesi.
Future<void> showSyncInfo(
  BuildContext context, {
  required String title,
  required String message,
  String? button,
}) {
  final l10n = AppLocalizations.of(context);
  return showKkSheet<void>(
    context,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(button ?? l10n.syncOk),
            ),
          ],
        ),
      );
    },
  );
}
