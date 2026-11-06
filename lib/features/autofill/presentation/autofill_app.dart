import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/presentation/autofill_pick_screen.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Doldurma bitti; ekran kapanırken kilit ekranı yeniden çizilmesin.
final autofillDoneProvider = NotifierProvider<AutofillDone, bool>(
  AutofillDone.new,
);

class AutofillDone extends Notifier<bool> {
  @override
  bool build() => false;

  void markDone() => state = true;
}

/// Otomatik doldurma ekranının uygulaması. Ana uygulamadan ayrı bir Flutter
/// motorunda, `autofillMain` giriş noktasıyla çalışır.
class AutofillApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeyKey',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AutofillHome(),
    );
  }
}

/// Neyin doldurulacağı ve kasanın durumuna göre doğru ekranı seçer.
class AutofillHome extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(autofillDoneProvider)) return const Scaffold();
    return ref
        .watch(autofillTargetProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => _Message(l10n.autofillNoRequest),
          data: (target) {
            if (target == null) return _Message(l10n.autofillNoRequest);
            return switch (ref.watch(vaultControllerProvider)) {
              VaultNotSetUp() => _Message(l10n.autofillNoVault),
              VaultUnavailable() ||
              VaultRecovering() => _Message(l10n.autofillVaultUnavailable),
              VaultLocked() => LockScreen(
                allowRecovery: false,
                subtitle: l10n.autofillFor(autofillTargetName(target)),
              ),
              VaultOpen() => AutofillPickScreen(target: target),
            };
          },
        );
  }
}

/// Kullanıcıya gösterilecek hedef adı: web sitesi veya uygulama.
String autofillTargetName(AutofillTarget target) =>
    target.webDomain ?? target.appLabel ?? target.packageName;

class _Message extends ConsumerWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      unawaited(ref.read(autofillBridgeProvider).cancel()),
                  child: Text(l10n.autofillClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
