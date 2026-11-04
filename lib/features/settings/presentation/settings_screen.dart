import 'package:flutter/material.dart';
import 'package:keykey/app/placeholder_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.navSettings,
      message: l10n.settingsPlaceholder,
      icon: Icons.settings_outlined,
    );
  }
}
