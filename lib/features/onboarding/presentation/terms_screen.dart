import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/web_page.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/onboarding/application/terms_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kullanım koşulları: verilerin nerede durduğu, nasıl korunduğu, nelerin
/// kullanıcının elinde olduğu ve garanti olmadığı.
///
/// Kasa kurulmadan ya da açılmadan önce bir kez gösterilir; kutu
/// işaretlenmeden devam edilemez. Kabul edilince yönlendirme kuruluma ya da
/// kilit ekranına götürür. [readOnly] ise Ayarlar'dan okunur, onay istemez.
/// Gerekçe `resources/docs/kullanici-gozuyle.md` belgesinde.
class TermsScreen extends ConsumerStatefulWidget {
  const new({this.readOnly = false, super.key});

  final bool readOnly;

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _agreed = false;
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    // Kabul yönlendirmeyi tetikler; ekran kendiliğinden değişir.
    await ref.read(termsAcceptedProvider.notifier).accept();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = [
      (l10n.termsDataTitle, l10n.termsDataBody),
      (l10n.termsCryptoTitle, l10n.termsCryptoBody),
      (l10n.termsSecretsTitle, l10n.termsSecretsBody),
      (l10n.termsBackupTitle, l10n.termsBackupBody),
      (l10n.termsSyncTitle, l10n.termsSyncBody),
      (l10n.termsDeviceTitle, l10n.termsDeviceBody),
      (l10n.termsOpenSourceTitle, l10n.termsOpenSourceBody),
      (l10n.termsWarrantyTitle, l10n.termsWarrantyBody),
    ];
    final text = ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(l10n.termsIntro),
        ),
        for (final (title, body) in sections)
          KkSection(
            title: title,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(body)),
            ],
          ),
        KkSection(
          title: l10n.settingsGroupAbout,
          children: [
            ListTile(
              title: Text(l10n.aboutPrivacy),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () =>
                  unawaited(openWebPage(context, ref, privacyPage(context))),
            ),
          ],
        ),
      ],
    );
    if (widget.readOnly) {
      return KkScaffold(
        appBar: kkAppBar(context, title: l10n.termsTitle),
        body: text,
      );
    }
    // Kurulmamış kasada geri tuşu tanıtıma döner; kasası olan kullanıcı
    // için koşullar ilk ekrandır, geri tuşu uygulamadan çıkar.
    final notSetUp = ref.watch(vaultControllerProvider) is VaultNotSetUp;
    return PopScope(
      canPop: !notSetUp,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && notSetUp) context.go(AppRoutes.intro);
      },
      child: KkScaffold(
        appBar: kkAppBar(context, title: l10n.termsTitle),
        body: Column(
          children: [
            Expanded(child: text),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      value: _agreed,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _agreed = value ?? false),
                      title: Text(l10n.termsAgree),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilledButton(
                        onPressed: _agreed && !_busy
                            ? () => unawaited(_accept())
                            : null,
                        child: Text(l10n.termsContinue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
