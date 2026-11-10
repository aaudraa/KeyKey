import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/presentation/autofill_pick_screen.dart';
import 'package:keykey/features/autofill/presentation/autofill_save_screen.dart';
import 'package:keykey/features/autofill/presentation/autofill_sheet_frame.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Doldurma veya kaydetme bitti; ekran kapanırken kilit ekranı yeniden
/// çizilmesin.
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

/// Neyin doldurulacağı ya da kaydedileceği ve kasanın durumuna göre doğru
/// ekranı seçer.
class AutofillHome extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Kapanırken saydam kalır; kilit ekranı yeniden çizilmez.
    if (ref.watch(autofillDoneProvider)) return const SizedBox.shrink();
    void cancel() => unawaited(ref.read(autofillBridgeProvider).cancel());
    return ref
        .watch(autofillTargetProvider)
        .when(
          loading: () => AutofillSheetFrame(
            onDismiss: cancel,
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => _Message(l10n.autofillNoRequest),
          data: (target) {
            if (target == null) return _Message(l10n.autofillNoRequest);
            final save = target.save;
            final name = autofillTargetName(target);
            return switch (ref.watch(vaultControllerProvider)) {
              VaultNotSetUp() => _Message(l10n.autofillNoVault),
              VaultUnavailable() ||
              VaultRecovering() => _Message(l10n.autofillVaultUnavailable),
              VaultLocked() => AutofillSheetFrame(
                onDismiss: cancel,
                child: LockScreen(
                  allowRecovery: false,
                  compact: true,
                  subtitle: save == null
                      ? l10n.autofillFor(name)
                      : l10n.autofillSaveFor(name),
                ),
              ),
              VaultOpen() when save != null => AutofillSaveScreen(
                target: target,
                save: save,
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
    void cancel() => unawaited(ref.read(autofillBridgeProvider).cancel());
    return AutofillSheetFrame(
      onDismiss: cancel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: cancel, child: Text(l10n.autofillClose)),
          ],
        ),
      ),
    );
  }
}
