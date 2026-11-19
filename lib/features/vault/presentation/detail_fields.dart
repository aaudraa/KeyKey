import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/ui/kk_copy_icon.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_secret_text.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/app/web_page.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/record_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Tek kartta, aralarında ince çizgi olan satırlar.
class DetailFieldGroup extends StatelessWidget {
  const new({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(
          Radius.circular(KkMetrics.cardRadius),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiketli bir değer. [hidden] ise göster düğmesine basılana kadar gizlidir.
///
/// Kilitlenince ekran kapandığı için açılan değer de yeniden gizlenir.
class DetailField extends ConsumerStatefulWidget {
  const new({
    required this.label,
    required this.value,
    super.key,
    this.hidden = false,
    this.page,
    this.display,
    this.copyText,
  });

  final String label;
  final String value;
  final bool hidden;

  /// Ekranda gösterilen biçim (ör. gruplanmış kart numarası); yoksa [value].
  final String? display;

  /// Kopyalanan metin (ör. gruplanmamış numara); yoksa [value].
  final String? copyText;

  /// Değer bir web sayfasıysa tarayıcıda açma düğmesi çıkar.
  final Uri? page;

  @override
  ConsumerState<DetailField> createState() => _DetailFieldState();
}

class _DetailFieldState extends ConsumerState<DetailField> {
  bool _revealed = false;

  @override
  void didUpdateWidget(DetailField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kayıt düzenlenince satırlar kayabilir; açılmış değer başka bir alana
    // ya da yeni değere geçmesin.
    if (oldWidget.label != widget.label || oldWidget.value != widget.value) {
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = KkGlass.of(context).accent;
    final concealed = widget.hidden && !_revealed;
    return ListTile(
      title: Text(widget.label, style: Theme.of(context).textTheme.labelMedium),
      // Gizliyken ekran okuyucu noktaları değil "gizli" okur.
      subtitle: Semantics(
        label: concealed ? l10n.secretConcealed : null,
        excludeSemantics: concealed,
        child: widget.hidden
            ? KkSecretText(
                text: widget.display ?? widget.value,
                revealed: _revealed,
                style: const TextStyle(fontFamily: 'monospace'),
              )
            : Text(widget.display ?? widget.value),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.hidden)
            IconButton(
              tooltip: concealed ? l10n.secretShow : l10n.secretHide,
              icon: Icon(
                concealed
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: accent,
              ),
              onPressed: () => setState(() => _revealed = !_revealed),
            ),
          if (widget.page case final page?)
            IconButton(
              tooltip: l10n.loginOpenSite,
              icon: Icon(Icons.open_in_new_rounded, color: accent),
              onPressed: () => unawaited(openWebPage(context, ref, page)),
            ),
          KkCopyIcon(
            tooltip: l10n.copyField(widget.label),
            color: accent,
            onCopy: () =>
                copySensitive(context, ref, widget.copyText ?? widget.value),
          ),
        ],
      ),
    );
  }
}

/// Kaydı çöp kutusuna taşır, ayrıntıyı kapatır ve geri alma bildirimi
/// gösterir. Kart ve not ayrıntısı ortak kullanır.
Future<void> moveRecordToTrash<C extends VaultItemContent<C>>(
  BuildContext context,
  RecordsController<C> controller,
  VaultRecord<C> item,
  AppLocalizations l10n,
) async {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  await controller.moveToTrash(item, DateTime.now().toUtc());
  if (context.mounted) context.pop();
  if (!rootContext.mounted) {
    hideKkSnack();
    return;
  }
  showKkSnack(
    rootContext,
    l10n.loginMovedToTrash,
    action: KkSnackAction(
      label: l10n.loginUndo,
      onPressed: () => unawaited(controller.restoreById(item.id)),
    ),
  );
}
