import 'package:flutter/material.dart';
import 'package:keykey/app/placeholder_screen.dart';

class SettingsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Ayarlar',
      message: 'Ayarlar yakında burada olacak.',
      icon: Icons.settings_outlined,
    );
  }
}
