import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_menu.dart';

/// Cam daire içinde simge düğmesi (geri oku, düzenle). Görünen boyu [size],
/// dokunma alanı en az 48 dp.
class KkCircleButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      style: kkCircleButtonStyle(KkGlass.of(context), size),
      onPressed: onPressed,
    );
  }
}

/// Sekmelerin kök ekranlarındaki üst çubuk: solda büyük, kalın başlık.
PreferredSizeWidget kkRootAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const [],
}) {
  final theme = Theme.of(context);
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 72,
    titleSpacing: 20,
    title: Semantics(
      header: true,
      child: Text(
        title,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
        ),
      ),
    ),
    actions: [...actions, const SizedBox(width: 8)],
  );
}

/// Alt ekranların üst çubuğu: geri gidilebiliyorsa solda cam daire içinde
/// Android geri oku, yanında başlık.
PreferredSizeWidget kkAppBar(
  BuildContext context, {
  String? title,
  List<Widget> actions = const [],
  Widget? titleTrailing,
}) {
  final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
  final theme = Theme.of(context);
  final titleText = title == null
      ? null
      : Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        );
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 64,
    leadingWidth: canPop ? 64 : null,
    titleSpacing: canPop ? 4 : 20,
    leading: canPop
        ? Center(
            child: KkCircleButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          )
        : null,
    title: titleTrailing == null
        ? titleText
        : Row(
            children: [
              if (titleText != null) Flexible(child: titleText),
              const SizedBox(width: 12),
              titleTrailing,
            ],
          ),
    actions: [...actions, const SizedBox(width: 8)],
  );
}

/// Form ekranlarının altındaki tek büyük düğme (ör. "Kaydet"). Klavye
/// açılınca klavyenin üstüne çıkar.
class KkBottomAction extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// İşlem sürüyor: düğmede ilerleme halkası, dokunuş etkisiz.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          child: busy
              ? Semantics(
                  label: label,
                  child: const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}
