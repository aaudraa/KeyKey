import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Altta yükselen cam bildirim. Öncekini kapatıp yerine geçer.
void showKkSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        shape: const StadiumBorder(),
        clipBehavior: Clip.none,
        content: GlassSurface(
          blur: true,
          strong: true,
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).hideCurrentSnackBar(reason: SnackBarClosedReason.action);
                    action.onPressed();
                  },
                  child: Text(action.label),
                ),
            ],
          ),
        ),
      ),
    );
}

/// Gizli bir değeri (parola, kod) güvenli panoya kopyalar ve bildirir. Pano
/// 30 saniye sonra temizlenir. Kasa bu arada kilitlenirse sessizce geçer:
/// yönlendirme zaten kilit ekranına gidiyor.
Future<void> copySensitive(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  final l10n = AppLocalizations.of(context);
  try {
    await ref.read(sensitiveClipboardProvider).copy(value);
  } on VaultLockedException {
    return;
  }
  if (!context.mounted) return;
  showKkSnack(
    context,
    l10n.copiedWillClear(SensitiveClipboard.clearAfter.inSeconds),
  );
}
