import 'package:flutter/material.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kayıtlar depodan okunamadığında listenin yerine çizilir: ne olduğunu
/// söyler ve yeniden denetir. Liste sonsuza dek "yükleniyor" kalmaz (#174,
/// V5).
class KkLoadFailed extends StatelessWidget {
  const new({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(l10n.listLoadFailed, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(l10n.listLoadRetry),
            ),
          ],
        ),
      ),
    );
  }
}
