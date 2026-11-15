import 'package:flutter/material.dart';

/// Tanıtım sayfasının hareketli çizimi. [active] olunca baştan oynar.
class IntroArt extends StatelessWidget {
  const new({required this.page, required this.active, super.key});

  final int page;
  final bool active;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
