import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ayarlardaki grup: başlık ve altında, aralarında ince çizgi olan
/// satırlar tek bir cam kartta.
///
/// Satırlar aynı boydadır: alt yazısı olmayan satır da iki satırlık boyda
/// durur. Alt yazılar tek satırdır; uzun açıklama [KkInfoRow] ile pencereye
/// taşınır.
class KkSection extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  /// Bir satırın en az boyu (normal yazıda).
  static const double rowHeight = 64;

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          GlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(26)),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(26)),
              child: Material(
                type: MaterialType.transparency,
                child: ListTileTheme.merge(
                  minTileHeight: rowHeight,
                  child: Column(
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        children[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satırın alt yazısı: tek satır, sığmazsa üç noktayla biter.
class KkRowSubtitle extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}

/// Sonunda küçük (i) düğmesi olan satır. Düğme [info] metnini alttan açılan
/// pencerede gösterir. Düğme satırdan ayrı bir öğedir; TalkBack'te ayrıca
/// odaklanır.
class KkInfoRow extends StatelessWidget {
  const new({
    required this.child,
    required this.infoTitle,
    required this.info,
    super.key,
  });

  final Widget child;
  final String infoTitle;
  final String info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: child),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: IconButton(
            tooltip: l10n.settingsMoreInfo,
            icon: const Icon(Icons.info_outline),
            onPressed: () => showKkSheet<void>(
              context,
              builder: (context) => KkSheetContent(
                title: infoTitle,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.otpClose),
                  ),
                ],
                child: Text(info),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Vurgu zeminli küçük simge kutusu: ayar satırlarında ve "+" kutusunda.
class KkIconBox extends StatelessWidget {
  const new({required this.icon, this.size = 36, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: glass.tint,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, size: size * 0.55, color: glass.accent),
      ),
    );
  }
}
