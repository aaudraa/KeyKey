import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_ambient.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/features/backup/application/auto_backup_controller.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/auto_lock_scope.dart';
import 'package:keykey/features/settings/application/theme_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

class KeyKeyApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kilitlenince açık bildirim kapanır; "Geri al" kilitten sonra basılamaz.
    ref
      ..listen(vaultControllerProvider, (_, next) {
        if (next is! VaultOpen) hideKkSnack();
      })
      // Otomatik yedek yalnızca ana uygulamada çalışır; durumu ayarlar okur.
      ..listen(autoBackupControllerProvider, (_, _) {});
    return MaterialApp.router(
      title: 'KeyKey',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => KkAmbient(
        enabled: ref.watch(ambientMotionProvider),
        child: AutoLockScope(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
