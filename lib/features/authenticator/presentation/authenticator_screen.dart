import 'package:flutter/material.dart';
import 'package:keykey/app/placeholder_screen.dart';

class AuthenticatorScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '2FA',
      message: 'Doğrulama kodların yakında burada olacak.',
      icon: Icons.shield_outlined,
    );
  }
}
