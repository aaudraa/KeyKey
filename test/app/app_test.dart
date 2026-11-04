import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/app.dart';

void main() {
  testWidgets('uygulama açılıyor', (tester) async {
    await tester.pumpWidget(const KeyKeyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('KeyKey'), findsOneWidget);
  });
}
