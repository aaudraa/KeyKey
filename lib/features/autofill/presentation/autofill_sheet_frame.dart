import 'package:flutter/material.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Doldurma ekranının çerçevesi: arkadaki uygulama hafifçe karartılmış
/// görünür, KeyKey'in içeriği alttan açılan yarım penceredir.
///
/// Karartılmış alana dokunmak ya da pencereyi aşağı kaydırmak [onDismiss]
/// çağırır; doldurma ekranında bu hiçbir şey doldurmadan kapatır.
class AutofillSheetFrame extends StatelessWidget {
  const new({
    required this.child,
    required this.onDismiss,
    this.expanded = false,
    super.key,
  });

  /// Tutamak; testler aşağı kaydırmayı bunun üzerinden yapar.
  static const handleKey = Key('autofill-sheet-handle');

  /// Karartmanın koyuluğu.
  static const double scrimOpacity = 0.35;

  /// Yarım pencerenin en çok boyu, ekranın oranı olarak.
  static const double compactHeight = 0.62;

  /// Uzamış pencerenin boyu, ekranın oranı olarak.
  static const double expandedHeight = 0.92;

  /// Bu hızdan hızlı aşağı kaydırma pencereyi kapatır.
  static const double dismissVelocity = 300;

  final Widget child;
  final VoidCallback onDismiss;

  /// `true` ise pencere neredeyse bütün ekranı kaplar (arama için).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final sheet = Material(
            color: theme.colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: handleKey,
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) > dismissVelocity) {
                        onDismiss();
                      }
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(child: child),
                ],
              ),
            ),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: ModalBarrier(
                  color: Colors.black.withValues(alpha: scrimOpacity),
                  onDismiss: onDismiss,
                  semanticsLabel: l10n.autofillClose,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: expanded
                    ? SizedBox(height: height * expandedHeight, child: sheet)
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: height * compactHeight,
                        ),
                        child: sheet,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pencerenin üst satırı: başlık ve kapatma düğmesi.
class AutofillSheetHeader extends StatelessWidget {
  const new({required this.title, required this.onClose, super.key});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.autofillClose,
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
