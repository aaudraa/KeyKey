import 'package:flutter/material.dart';
import 'package:keykey/app/placeholder_screen.dart';

class VaultScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Kasa',
      message: 'Parolaların yakında burada olacak.',
      icon: Icons.lock_outline,
    );
  }
}
