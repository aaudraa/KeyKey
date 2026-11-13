import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ayarlardaki grup: başlık ve altında, aralarında ince çizgi olan
/// satırlar tek bir cam kartta.
///
/// Satırlar aynı boydadır: alt yazısı olmayan satır da iki satırlık boyda
/// durur. Alt yazılar tek satırdır; uzun açıklama [KkInfoButton] ile
/// pencereye taşınır.
class KkSection extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  /// Bir satırın en az boyu (normal yazıda).
  static const double rowHeight = KkMetrics.rowHeight;

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
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(KkMetrics.cardRadius),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListTileTheme.merge(
                  minTileHeight: rowHeight,
                  minVerticalPadding: 7,
                  titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: KkMetrics.rowTitle,
                    color: theme.colorScheme.onSurface,
                  ),
                  subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: KkMetrics.rowSubtitle,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: rowHeight,
                          ),
                          child: children[i],
                        ),
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

/// Küçük (i) düğmesi: [info] metnini alttan açılan pencerede gösterir.
/// Satırın sonunda, anahtarın ya da okun hemen solunda durur; TalkBack'te
/// satırdan ayrı odaklanır.
class KkInfoButton extends StatelessWidget {
  const new({required this.title, required this.info, super.key});

  final String title;
  final String info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.settingsMoreInfo,
      icon: Icon(
        Icons.info_outline,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () => showKkSheet<void>(
        context,
        builder: (context) => KkSheetContent(
          title: title,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.otpClose),
            ),
          ],
          child: Text(info),
        ),
      ),
    );
  }
}

/// Ayar satırlarındaki ve "+" kutusundaki simge: kutusuz, yazı renginde.
class KkIconBox extends StatelessWidget {
  const new({required this.icon, this.size = 22, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Icon(
        icon,
        size: size,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
