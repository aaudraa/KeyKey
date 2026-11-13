import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/ui/kk_switch.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('tr'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('KkSwitch', () {
    testWidgets('36×21 görünür, 48×48 dokunulur', (tester) async {
      await tester.pumpWidget(_host(KkSwitch(value: true, onChanged: (_) {})));
      expect(tester.getSize(find.byType(KkSwitch)), const Size(48, 48));
      expect(tester.getSize(find.byKey(KkSwitch.trackKey)), const Size(36, 21));
    });

    testWidgets('dokununca değer çevrilir, açıkken iz yazı renginde', (
      tester,
    ) async {
      bool? got;
      await tester.pumpWidget(
        _host(KkSwitch(value: true, onChanged: (v) => got = v)),
      );
      final track = tester.widget<AnimatedContainer>(
        find.byKey(KkSwitch.trackKey),
      );
      expect(
        (track.decoration! as BoxDecoration).color,
        AppTheme.light.colorScheme.onSurface,
      );
      await tester.tap(find.byType(KkSwitch));
      expect(got, isFalse);
    });

    testWidgets('etkisizken dokunuş yok, ekran okuyucu etkisiz okur', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const KkSwitch(value: false, onChanged: null)),
      );
      await tester.tap(find.byType(KkSwitch));
      final semantics = tester.getSemantics(find.byType(KkSwitch));
      expect(
        semantics,
        matchesSemantics(hasToggledState: true, hasEnabledState: true),
      );
      handle.dispose();
    });
  });

  group('KkSwitchTile', () {
    testWidgets('satıra dokunmak değeri çevirir', (tester) async {
      var value = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => KkSwitchTile(
              title: const Text('Parmak iziyle aç'),
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Parmak iziyle aç'));
      await tester.pump();
      expect(value, isTrue);
      expect(
        tester.widget<KkSwitchTile>(find.byType(KkSwitchTile)).value,
        isTrue,
      );
    });

    testWidgets('(i) anahtarın solunda; dokunmak pencere açar, değeri '
        'değiştirmez', (tester) async {
      var changed = false;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          KkSwitchTile(
            title: const Text('Parmak iziyle aç'),
            value: false,
            onChanged: (_) => changed = true,
            infoTitle: 'Parmak izi',
            info: 'Kasayı parmak izinle açarsın.',
          ),
        ),
      );
      final info = find.byType(KkInfoButton);
      expect(
        tester.getTopLeft(info).dx,
        lessThan(tester.getTopLeft(find.byType(KkSwitch)).dx),
      );
      expect(
        find.descendant(of: info, matching: find.byTooltip('Açıklama')),
        findsOneWidget,
      );
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(changed, isFalse);
      expect(find.text('Kasayı parmak izinle açarsın.'), findsOneWidget);
      handle.dispose();
    });
  });
}
