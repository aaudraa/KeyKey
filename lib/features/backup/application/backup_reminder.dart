import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';

/// Hatırlatmanın türü.
enum BackupReminder {
  /// Hiç yedek alınmadı ama kasada kayıt var.
  never,

  /// Son yedekten sonra kayıt değişti ve son yedek eskidi.
  stale,
}

/// Yedek hatırlatıcısının kuralı. Güvenlik tasarımı belgesinin "Yedek
/// hatırlatıcısı" bölümünde.
abstract final class BackupReminderRule {
  /// Son yedek bundan eskiyse hatırlatılır.
  static const staleAfter = Duration(days: 14);

  /// "Sonra" seçilince hatırlatma bu kadar susar.
  static const snooze = Duration(days: 7);

  /// Gösterilecek hatırlatma; gerekmiyorsa `null`.
  ///
  /// [latestChange], parola ve 2FA kayıtlarının en son değiştiği an; kasa
  /// boşsa `null`.
  static BackupReminder? due({
    required DateTime now,
    required DateTime? latestChange,
    required DateTime? lastBackupAt,
    required DateTime? snoozedUntil,
  }) {
    if (latestChange == null) return null;
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) return null;
    if (lastBackupAt == null) return BackupReminder.never;
    if (!latestChange.isAfter(lastBackupAt)) return null;
    if (now.difference(lastBackupAt) < staleAfter) return null;
    return BackupReminder.stale;
  }
}

/// Kasa ekranında gösterilecek hatırlatma. Kayıtlar veya ayarlar değişince
/// yeniden hesaplanır.
final backupReminderProvider = FutureProvider<BackupReminder?>((ref) async {
  final status = ref.watch(vaultControllerProvider);
  final settings = ref.watch(settingsControllerProvider);
  if (status is! VaultOpen || settings == null) return null;
  // Listeler değişince (ekleme, silme, içe aktarma) yeniden bakılır.
  ref
    ..watch(loginsControllerProvider)
    ..watch(otpsControllerProvider);
  final latestChange = await ref.read(backupServiceProvider).latestChange();
  return BackupReminderRule.due(
    now: ref.read(backupClockProvider)(),
    latestChange: latestChange,
    lastBackupAt: settings.lastBackupAt,
    snoozedUntil: settings.backupReminderSnoozedUntil,
  );
});
