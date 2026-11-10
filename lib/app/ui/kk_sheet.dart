import 'package:flutter/material.dart';

/// Alttan açılan pencere. [expandable] ise kullanıcı yukarı çekerek
/// büyütebilir (uzun listeler ve arama için).
Future<T?> showKkSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool expandable = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      if (!expandable) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(child: builder(context)),
        );
      }
      return DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, controller) => PrimaryScrollController(
          controller: controller,
          child: builder(context),
        ),
      );
    },
  );
}

/// Onay penceresi; ortada açılan kutunun yerine alttan açılır. Onaylanırsa
/// `true`, vazgeçilir ya da kapatılırsa `false`.
Future<bool> showKkConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
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
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
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
