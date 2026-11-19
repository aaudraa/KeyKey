import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_snack.dart';

/// Seçilebilir gizli metin (güvenli not).
///
/// Sistemin seçim menüsü panoya doğrudan yazar; süre dolunca silinmez ve
/// hassas işareti taşımaz. Burada menüde yalnızca "Kopyala" ve "Tümünü seç"
/// vardır, kopyalama da [copySensitive] üzerinden yapılır.
class SensitiveSelectableText extends ConsumerWidget {
  const new(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = MaterialLocalizations.of(context);
    return SelectableText(
      text,
      style: style,
      // Menünün kendi bağlamı menü kapanınca gider; bildirim, metnin
      // bağlamıyla gösterilir.
      contextMenuBuilder: (_, editable) {
        final value = editable.textEditingValue;
        final selected = value.selection.textInside(value.text);
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editable.contextMenuAnchors,
          buttonItems: [
            if (selected.isNotEmpty)
              ContextMenuButtonItem(
                label: localizations.copyButtonLabel,
                onPressed: () {
                  editable.hideToolbar();
                  unawaited(copySensitive(context, ref, selected));
                },
              ),
            if (selected.length < value.text.length)
              ContextMenuButtonItem(
                label: localizations.selectAllButtonLabel,
                onPressed: () =>
                    editable.selectAll(SelectionChangedCause.toolbar),
              ),
          ],
        );
      },
    );
  }
}
