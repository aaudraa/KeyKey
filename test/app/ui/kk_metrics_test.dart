import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Siyah-beyaz tasarımın küçük ölçüleri
/// (`resources/docs/tasarim-siyah-beyaz.md`, "Ölçüler").
Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('tr'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: child,
  );
}

Widget _settings() => Scaffold(
  body: ListView(
    children: const [
      KkSection(
        title: 'Güvenlik',
        children: [
          ListTile(
            key: Key('alt-yazili'),
            leading: KkIconBox(icon: Icons.lock_rounded),
            title: Text('Otomatik kilit'),
            subtitle: KkRowSubtitle('1 dakika'),
          ),
          ListTile(
            key: Key('yalin'),
            leading: KkIconBox(icon: Icons.info_rounded),
            title: Text('Sürüm'),
          ),
        ],
      ),
    ],
  ),
);

Widget _card() => const Scaffold(
  body: Column(
    children: [
      KkCard(key: Key('kart'), title: Text('GitHub'), subtitle: Text('furky')),
    ],
  ),
);

void main() {
  test('ölçü değerleri belgedeki gibi', () {
    expect(KkMetrics.rootTitle, 22);
    expect(KkMetrics.subTitle, 17);
    expect(KkMetrics.cardHeight, 54);
    expect(KkMetrics.rowHeight, 48);
    expect(KkMetrics.buttonHeight, 44);
    expect(KkMetrics.buttonRadius, 14);
    expect(KkMetrics.cardRadius, 16);
    expect(KkMetrics.navHeight, 52);
    expect(KkMetrics.addSize, 40);
    expect(KkMetrics.minTouch, 48);
    expect(KkMetrics.minFont, greaterThanOrEqualTo(11));
  });

  testWidgets('kart 54, ayar satırları 48 dp', (tester) async {
    await tester.pumpWidget(_host(_card()));
    expect(tester.getSize(find.byKey(const Key('kart'))).height, 54);

    await tester.pumpWidget(_host(_settings()));
    expect(tester.getSize(find.byKey(const Key('alt-yazili'))).height, 48);
    expect(tester.getSize(find.byKey(const Key('yalin'))).height, 48);
  });

  testWidgets('kart ve satır yazıları küçük', (tester) async {
    await tester.pumpWidget(_host(_card()));
    final title = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('GitHub'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(title.style.fontSize, KkMetrics.cardTitle);

    await tester.pumpWidget(_host(_settings()));
    final row = tester.renderObject<RenderParagraph>(find.text('Sürüm'));
    expect(row.text.style?.fontSize, KkMetrics.rowTitle);
  });

  testWidgets('başlıklar 22 ve 17', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Scaffold(
            appBar: kkRootAppBar(context, title: 'Kasa'),
            body: const SizedBox(),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('Kasa')).style?.fontSize, 22);

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Scaffold(
            appBar: kkAppBar(context, title: 'Ayrıntı'),
            body: const SizedBox(),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('Ayrıntı')).style?.fontSize, 17);
  });

  testWidgets('ana düğme 44 dp görünür, 48 dp dokunulur', (tester) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          bottomNavigationBar: KkBottomAction(
            label: 'Kaydet',
            onPressed: () {},
          ),
          body: const SizedBox(),
        ),
      ),
    );
    final button = find.byType(FilledButton);
    final visible = find.descendant(
      of: button,
      matching: find.byType(Material),
    );
    expect(tester.getSize(visible.first).height, 44);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('alt menü 52 dp, "+" 40 dp görünür, 48 dp dokunulur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          bottomNavigationBar: GlassNavBar(
            selectedIndex: 0,
            onSelected: (_) {},
            items: const [
              GlassNavItem(
                icon: Icons.lock_outline,
                selectedIcon: Icons.lock,
                label: 'Kasa',
              ),
              GlassNavItem(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Ayarlar',
              ),
            ],
            onAdd: () {},
            addOpen: false,
            addLabel: 'Ekle',
            closeLabel: 'Kapat',
          ),
          body: const SizedBox(),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(GlassNavBar.pillKey)).height, 52);
    expect(tester.getSize(find.byKey(GlassNavBar.addKey)), const Size(48, 48));
    final circle = find.descendant(
      of: find.byKey(GlassNavBar.addKey),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(circle.first), const Size(40, 40));
  });

  testWidgets('form alanı en çok 54 dp', (tester) async {
    await tester.pumpWidget(
      _host(
        const Scaffold(
          body: Column(
            children: [
              KkFieldCard(
                child: TextField(decoration: InputDecoration(labelText: 'Ad')),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(KkFieldCard)).height - 10,
      lessThanOrEqualTo(54),
    );
  });

  testWidgets('%200 yazıda kart ve satır büyür, taşmaz', (tester) async {
    await tester.pumpWidget(_host(_card(), textScale: 2));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('kart'))).height,
      greaterThan(54),
    );

    await tester.pumpWidget(_host(_settings(), textScale: 2));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('alt-yazili'))).height,
      greaterThan(48),
    );
  });
}
