import 'package:flutter/material.dart';
import 'package:keykey/app/placeholder_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

class AuthenticatorScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.navAuthenticator,
      message: l10n.authenticatorPlaceholder,
      icon: Icons.shield_outlined,
    );
  }
}
