import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_section.dart';

void main() {
  testWidgets('grup tek cam kart, satırlar 48 dp, simge kutusu okunmaz', (
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
    expect(tester.getSize(find.byKey(const Key('satir'))).height, 48);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(Divider), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('satir'))).label,
      'Otomatik kilit',
    );
    handle.dispose();
  });

  testWidgets('simge kutusuz, yazı renginde', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: KkIconBox(icon: Icons.lock_rounded)),
        ),
      ),
    );

    final box = find.byType(KkIconBox);
    expect(
      find.descendant(of: box, matching: find.byType(Container)),
      findsNothing,
    );
    expect(
      find.descendant(of: box, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.lock_rounded));
    expect(icon.color, AppTheme.light.colorScheme.onSurface);
    expect(tester.getSize(box), const Size(22, 22));
  });
}
