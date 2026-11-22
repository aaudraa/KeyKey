import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/app/ui/sensitive_copy_shortcuts.dart';

/// Seçilebilir gizli metin (güvenli not).
///
/// Sistemin seçim menüsü panoya doğrudan yazar; süre dolunca silinmez ve
/// hassas işareti taşımaz. Burada menüde yalnızca "Kopyala" ve "Tümünü seç"
/// vardır, kopyalama da [copySensitive] üzerinden yapılır.
class SensitiveSelectableText extends ConsumerStatefulWidget {
  const new(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  ConsumerState<SensitiveSelectableText> createState() =>
      _SensitiveSelectableTextState();
}

class _SensitiveSelectableTextState
    extends ConsumerState<SensitiveSelectableText> {
  /// Donanım klavyesiyle kopyalama için son seçim.
  TextSelection _selection = const TextSelection.collapsed(offset: -1);

  void _copyByKeyboard() {
    final selection = _selection;
    if (!selection.isValid || selection.isCollapsed) return;
    if (selection.end > widget.text.length) return;
    unawaited(copySensitive(context, ref, selection.textInside(widget.text)));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return SensitiveCopyShortcuts(
      onCopy: _copyByKeyboard,
      child: _text(localizations),
    );
  }

  Widget _text(MaterialLocalizations localizations) {
    final text = widget.text;
    return SelectableText(
      text,
      style: widget.style,
      onSelectionChanged: (selection, _) => _selection = selection,
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
