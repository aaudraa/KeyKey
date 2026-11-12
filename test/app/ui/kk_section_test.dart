import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_section.dart';

void main() {
  testWidgets('grup tek cam kart, satırlar 64 dp, simge kutusu okunmaz', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              KkSection(
                title: 'Güvenlik',
                children: [
                  ListTile(
                    key: const Key('satir'),
                    leading: const KkIconBox(icon: Icons.lock_rounded),
                    title: const Text('Otomatik kilit'),
                    onTap: () {},
                  ),
                  const ListTile(title: Text('Parmak izi')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Güvenlik'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('satir'))).height, 64);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(Divider), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('satir'))).label,
      'Otomatik kilit',
    );
    handle.dispose();
  });
}
