import 'package:flutter/material.dart';

class KeyKeyApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'KeyKey',
      home: Scaffold(body: Center(child: Text('KeyKey'))),
    );
  }
}
