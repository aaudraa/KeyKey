import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Pencerenin üst köşeleri.
const _sheetRadius = BorderRadius.vertical(top: Radius.circular(30));

/// Alttan açılan cam pencere. Yaylanarak açılır, aşağı çekince parmağı
/// izler. [expandable] ise kullanıcı yukarı çekerek büyütebilir (uzun
/// listeler ve arama için).
Future<T?> showKkSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool expandable = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Sekmenin kendi navigatöründe açılırsa yüzen menünün altında kalır.
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    barrierColor: KkGlass.of(context).scrim,
    sheetAnimationStyle: AnimationStyle(
      duration: KkMotion.of(context, KkMotion.panelOpen),
      reverseDuration: KkMotion.of(context, KkMotion.panelClose),
      curve: KkMotion.spring,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (context) {
      if (!expandable) {
        return _SheetFrame(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(child: builder(context)),
          ),
        );
      }
      return DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, controller) => _SheetFrame(
          child: PrimaryScrollController(
            controller: controller,
            child: builder(context),
          ),
        ),
      );
    },
  );
}

/// Pencerenin cam gövdesi ve tutamağı. Cam, yay açılışında pencere yerini
/// biraz aşınca altta boşluk görünmesin diye ekranın altına doğru uzar.
class _SheetFrame extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -80,
          child: GlassSurface(
            blur: true,
            strong: true,
            borderRadius: _sheetRadius,
            child: SizedBox.expand(),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 14),
              child: ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: glass.accent.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ],
    );
  }
}

/// Alt penceredeki düzen: başlık, içerik ve en altta düğmeler. Eski
/// `AlertDialog` düzeninin karşılığı.
class KkSheetContent extends StatelessWidget {
  const new({
    required this.title,
    required this.actions,
    this.child,
    super.key,
  });

  final String title;
  final Widget? child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (child != null) ...[const SizedBox(height: 12), child!],
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    );
  }
}

/// Onay penceresi; ortada açılan kutunun yerine alttan açılır. Onaylanırsa
/// `true`, vazgeçilir ya da kapatılırsa `false`.
Future<bool> showKkConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? message,
  bool destructive = false,
}) async {
  final result = await showKkSheet<bool>(
    context,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: destructive
                  ? ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(scheme.onError),
                      backgroundBuilder: (context, states, child) =>
                          DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const StadiumBorder(),
                              color: scheme.error,
                            ),
                            child: child,
                          ),
                    )
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
