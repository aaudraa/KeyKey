import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_section.dart';

void main() {
  testWidgets('grup tek cam kart, satırlar 56 dp, simge kutusu okunmaz', (
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
    expect(tester.getSize(find.byKey(const Key('satir'))).height, 56);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(Divider), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('satir'))).label,
      'Otomatik kilit',
    );
    handle.dispose();
  });

  testWidgets('alt yazılı satırda yazılar dikeyde ortalı', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: const [
              KkSection(
                title: 'Yedek',
                children: [
                  ListTile(
                    key: Key('satir'),
                    leading: KkIconBox(icon: Icons.input_rounded),
                    title: Text('Yedekten geri yükle'),
                    subtitle: KkRowSubtitle('Bir yedek dosyası aç.'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final row = tester.getRect(find.byKey(const Key('satir')));
    final title = tester.getRect(find.text('Yedekten geri yükle'));
    final subtitle = tester.getRect(find.text('Bir yedek dosyası aç.'));
    expect(
      (title.top - row.top) - (row.bottom - subtitle.bottom),
      inInclusiveRange(-1.5, 1.5),
    );
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
    expect(tester.getSize(box), const Size(24, 24));
  });
}
