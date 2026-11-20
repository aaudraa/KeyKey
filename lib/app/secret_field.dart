import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/features/lock/presentation/auto_lock_scope.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Gizli olmayan bir kutunun, ayar açıkken kullanacağı klavye.
enum PlainKeyboard {
  /// Normal klavye, cümle başı büyük harf: kayıt adı, klasör, arama.
  text,

  /// Adres klavyesi (`/`, `.com`): web adresi.
  url,
}

/// Ana parola ve kurtarma anahtarı için metin kutusu.
///
/// Klavye öğrenmesi ve otomatik düzeltme kapalıdır, böylece yazılan metin
/// klavyenin sözlüğüne girmez. Seçim menüsünde kes ve kopyala hassas panodan
/// geçer; metni başka uygulamalara gönderen düğmeler (paylaş, ara, çevir)
/// yoktur.
class SecretField extends ConsumerStatefulWidget {
  const new({
    required this.controller,
    required this.label,
    this.obscure = true,
    this.errorText,
    this.helperText,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.onChanged,
    this.maxLines = 1,
    this.multiline = false,
    this.trailing,
    this.initiallyVisible = false,
    this.inputFormatters,
    this.style,
    this.search = false,
    this.focusNode,
    this.keyboardType,
    this.plain,
    super.key,
  });

  /// Gizli olmayan kutu: ayarlarda "normal klavye" açıksa bu klavye açılır.
  /// Verilmezse, kutu gizliyse ya da [keyboardType] verildiyse her zaman
  /// öğrenmesiz klavye. Öneri, düzeltme ve öğrenme isteği iki durumda da
  /// kapalıdır.
  final PlainKeyboard? plain;

  final FocusNode? focusNode;

  /// Verilmezse çok satırlıda `multiline`, diğerlerinde `visiblePassword`.
  /// Rakam klavyesi (kart numarası, PIN) öneri göstermez.
  final TextInputType? keyboardType;

  /// Arama kutusu: tam yuvarlak, başında büyüteç; [label] silik yazı olarak
  /// kutunun içinde durur.
  final bool search;

  /// `true` ise gizli kutu açık başlar; gizle düğmesi yine çıkar.
  final bool initiallyVisible;

  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;

  /// Göster düğmesinin yanına konan ek düğme, örneğin parola üretici.
  final Widget? trailing;

  /// Gizli olmayan kutularda birden fazla satıra izin verir.
  final int maxLines;

  /// `true` ise Enter yeni satır açar, notlar için.
  final bool multiline;

  final TextEditingController controller;
  final String label;

  /// `true` ise metin gizlenir ve göster düğmesi çıkar.
  final bool obscure;
  final String? errorText;
  final String? helperText;
  final bool autofocus;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  ConsumerState<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends ConsumerState<SecretField> {
  late bool _visible = widget.initiallyVisible;

  /// Menüde kalan düğmeler. Gizli kutuda Flutter kes ve kopyalayı zaten
  /// göstermez.
  static const Set<ContextMenuButtonKind> _allowed = {
    ContextMenuButtonKind.cut,
    ContextMenuButtonKind.copy,
    ContextMenuButtonKind.paste,
    ContextMenuButtonKind.selectAll,
    ContextMenuButtonKind.delete,
  };

  /// Sistemin menüsü panoya doğrudan yazar: hassas işareti yoktur, süre
  /// dolunca silinmez, klavyenin pano geçmişine girer.
  Widget _contextMenu(BuildContext _, EditableTextState editable) =>
      AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editable.contextMenuAnchors,
        buttonItems: [
          for (final item in editable.contextMenuButtonItems)
            if (_allowed.contains(item.kind))
              switch (item.kind) {
                ContextMenuButtonKind.copy => item.copyWith(
                  onPressed: () => _copy(editable, cut: false),
                ),
                ContextMenuButtonKind.cut => item.copyWith(
                  onPressed: () => _copy(editable, cut: true),
                ),
                _ => item,
              },
        ],
      );

  void _copy(EditableTextState editable, {required bool cut}) {
    final value = editable.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final selected = selection.textInside(value.text);
    editable
      ..userUpdateTextEditingValue(
        cut
            ? TextEditingValue(
                text:
                    selection.textBefore(value.text) +
                    selection.textAfter(value.text),
                selection: TextSelection.collapsed(offset: selection.start),
              )
            // Android'da kopyaladıktan sonra seçim kapanır.
            : value.copyWith(
                selection: TextSelection.collapsed(offset: selection.end),
              ),
        SelectionChangedCause.toolbar,
      )
      ..hideToolbar();
    unawaited(copySensitive(context, ref, selected));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plain = widget.obscure || widget.keyboardType != null
        ? null
        : widget.plain;
    final usePlain = plain != null && ref.watch(plainKeyboardProvider);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      // Kapatmak yerine salt okunur: odak ve klavye korunur, kullanıcı yanlış
      // paroladan sonra kutuya yeniden dokunmak zorunda kalmaz.
      readOnly: !widget.enabled,
      obscureText: widget.obscure && !_visible,
      inputFormatters: widget.inputFormatters,
      contextMenuBuilder: _contextMenu,
      style: widget.style,
      // visiblePassword, çoğu klavyede öneri ve öğrenmeyi de kapatır.
      keyboardType:
          widget.keyboardType ??
          switch ((usePlain, plain)) {
            (true, PlainKeyboard.text) => TextInputType.text,
            (true, PlainKeyboard.url) => TextInputType.url,
            _ when widget.multiline => TextInputType.multiline,
            _ => TextInputType.visiblePassword,
          },
      textCapitalization: usePlain && plain == PlainKeyboard.text
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      minLines: 1,
      textInputAction: widget.textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      onSubmitted: widget.onSubmitted,
      onChanged: (value) {
        // Yazmak da kullanım sayılır, otomatik kilit süresi yenilenir.
        AutoLockScope.reportActivity(context);
        widget.onChanged?.call(value);
      },
      decoration: InputDecoration(
        labelText: widget.search ? null : widget.label,
        hintText: widget.search ? widget.label : null,
        prefixIcon: widget.search ? const Icon(Icons.search_rounded) : null,
        enabledBorder: widget.search
            ? const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
                borderSide: BorderSide.none,
              )
            : null,
        focusedBorder: widget.search
            ? OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(28)),
                borderSide: BorderSide(
                  color: KkGlass.of(context).accent,
                  width: 1.5,
                ),
              )
            : null,
        errorText: widget.errorText,
        helperText: widget.helperText,
        helperMaxLines: 3,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
        suffixIcon: widget.obscure || widget.trailing != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?widget.trailing,
                  if (widget.obscure)
                    IconButton(
                      tooltip: _visible ? l10n.secretHide : l10n.secretShow,
                      icon: Icon(
                        _visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _visible = !_visible),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}
