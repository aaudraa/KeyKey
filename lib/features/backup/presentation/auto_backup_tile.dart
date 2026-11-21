import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/app/ui/kk_switch.dart';
import 'package:keykey/core/platform/backup_folders.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/auto_backup_controller.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ayarlardaki otomatik yedek anahtarı. Açıkken altında
/// [AutoBackupChangeFolderTile] ve [AutoBackupNowTile] gelir.
class AutoBackupSwitchTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final folder = settings?.autoBackupFolder;
    final problem = ref.watch(autoBackupControllerProvider).problem;
    final Widget subtitle;
    if (folder == null) {
      subtitle = KkRowSubtitle(l10n.autoBackupOff);
    } else if (problem != null) {
      subtitle = Text(switch (problem) {
        AutoBackupProblem.noAccess => l10n.autoBackupNoAccess,
        AutoBackupProblem.writeFailed => l10n.autoBackupWriteFailed,
      }, style: TextStyle(color: theme.colorScheme.error));
    } else {
      subtitle = KkRowSubtitle(l10n.autoBackupOn(folder.name));
    }
    return KkSwitchTile(
      secondary: const KkIconBox(icon: Icons.sync_rounded),
      title: Text(l10n.autoBackupTitle),
      subtitle: subtitle,
      infoTitle: l10n.autoBackupTitle,
      info: l10n.autoBackupIntro,
      value: folder != null,
      onChanged: settings == null
          ? null
          : (on) =>
                unawaited(on ? _turnOn(context, ref) : _turnOff(context, ref)),
    );
  }
}

/// Otomatik yedeği başka bir klasöre yönlendirir.
class AutoBackupChangeFolderTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const KkIconBox(icon: Icons.folder_open_rounded),
    title: Text(AppLocalizations.of(context).autoBackupChangeFolder),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => unawaited(_pickFolder(context, ref)),
  );
}

/// Klasöre hemen bir yedek yazar.
class AutoBackupNowTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const KkIconBox(icon: Icons.backup_rounded),
    title: Text(AppLocalizations.of(context).autoBackupNow),
    onTap: () => unawaited(_backUpNow(context, ref)),
  );
}

Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final go = await showKkConfirm(
    context,
    title: l10n.autoBackupTitle,
    message: l10n.autoBackupIntro,
    confirmLabel: l10n.autoBackupChooseFolder,
    cancelLabel: l10n.autoBackupCancel,
  );
  if (!go || !context.mounted) return;
  await _pickFolder(context, ref, enabling: true);
}

/// Klasör seçer ve otomatik yedeği ona yönlendirir. Seçiciden vazgeçilirse
/// hiçbir şey değişmez.
Future<void> _pickFolder(
  BuildContext context,
  WidgetRef ref, {
  bool enabling = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final snack = kkSnackFor(context);
  final picked = await ref
      .read(externalActivityGateProvider.notifier)
      .run(() => ref.read(backupFoldersProvider).pick());
  switch (picked) {
    case FolderPickCancelled():
      return;
    case FolderPickFailed():
      snack(l10n.autoBackupPickFailed);
      return;
    case FolderPicked():
      final bool written;
      try {
        written = await ref
            .read(autoBackupControllerProvider.notifier)
            .useFolder(picked);
      } on VaultLockedException {
        return;
      }
      if (!written) {
        snack(l10n.autoBackupFailed);
      } else {
        snack(enabling ? l10n.autoBackupEnabled : l10n.autoBackupSaved);
      }
  }
}

Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final snack = kkSnackFor(context);
  try {
    await ref.read(autoBackupControllerProvider.notifier).disable();
  } on VaultLockedException {
    return;
  }
  snack(l10n.autoBackupDisabled);
}

Future<void> _backUpNow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final snack = kkSnackFor(context);
  final written = await ref
      .read(autoBackupControllerProvider.notifier)
      .backUpNow();
  snack(written ? l10n.autoBackupSaved : l10n.autoBackupFailed);
}
