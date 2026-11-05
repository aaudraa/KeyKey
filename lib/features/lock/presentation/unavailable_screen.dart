import 'package:flutter/material.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kasa dosyası okunamıyor. Dosyaya dokunulmaz, kullanıcı veri kaybetmez.
class UnavailableScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.unavailableTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(l10n.unavailableMessage, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
