import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/platform/web_links.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// KeyKey'in kaynak kodu ve sorun listesi.
const keyKeyRepository = 'https://github.com/aaudraa/KeyKey';

/// Gizlilik bildirimi arayüz dilinde; Türkçe dışında İngilizcesi.
Uri privacyPage(BuildContext context) {
  final file = Localizations.localeOf(context).languageCode == 'tr'
      ? 'gizlilik.md'
      : 'privacy.md';
  return Uri.parse('$keyKeyRepository/blob/main/resources/docs/$file');
}

/// Sayfayı tarayıcıda açar; açacak uygulama yoksa kullanıcıya söyler.
/// KeyKey arka plana geçtiği için kasa her zamanki gibi kilitlenir.
Future<void> openWebPage(BuildContext context, WidgetRef ref, Uri page) async {
  final show = kkSnackFor(context);
  final l10n = AppLocalizations.of(context);
  final bool opened;
  try {
    opened = await ref.read(webLinksProvider).open(page);
  } on Exception {
    show(l10n.webPageNoBrowser);
    return;
  }
  if (!opened) show(l10n.webPageNoBrowser);
}
