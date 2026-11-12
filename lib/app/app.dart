import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/features/lock/presentation/auto_lock_scope.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

class KeyKeyApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'KeyKey',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      // Geçici: ekranlar KkScaffold'a taşınana kadar düz zemin (Görev 13'te
      // kaldırılır).
      builder: (context, child) => ColoredBox(
        color: KkGlass.of(context).ground,
        child: AutoLockScope(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
