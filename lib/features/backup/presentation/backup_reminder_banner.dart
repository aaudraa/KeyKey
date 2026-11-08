import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/backup_reminder.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/presentation/backup_section.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kasa ekranının üstünde, gerekiyorsa yedek almayı hatırlatır.
///
/// Bildirim değildir; yalnızca uygulama açıkken görünür.
class BackupReminderBanner extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BackupReminderBanner> createState() =>
      _BackupReminderBannerState();
}

class _BackupReminderBannerState extends ConsumerState<BackupReminderBanner> {
  bool _busy = false;

  Future<void> _backUp() async {
    setState(() => _busy = true);
    try {
      await backUpVault(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _later() async {
    final now = ref.read(backupClockProvider)();
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .snoozeBackupReminder(now.add(BackupReminderRule.snooze));
    } on VaultLockedException {
      // Kasa kilitlendi; hatırlatma bir sonraki açılışta yine çıkar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminder = ref.watch(backupReminderProvider).value;
    if (reminder == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.backup_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      switch (reminder) {
                        BackupReminder.never => l10n.backupReminderNever,
                        BackupReminder.stale => l10n.backupReminderStale,
                      },
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_later()),
                    child: Text(l10n.backupReminderLater),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_backUp()),
                    child: Text(l10n.backupCreate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
