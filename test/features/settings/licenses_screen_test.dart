import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/license_catalog_provider.dart';
import 'package:keykey/features/settings/data/license_catalog.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

const _gpl =
    'GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007\n\n'
    'THERE IS NO WARRANTY FOR THE PROGRAM';
const _isc =
    'ISC License\n\nPermission to use, copy, modify, and/or distribute this '
    'software for any purpose';
const _bsd3 =
    'Redistribution and use in source and binary forms, with or without '
    'modification, are permitted. Neither the name of the copyright holder '
    'nor the names of its contributors may be used';
const _apache = 'Apache License\nVersion 2.0, January 2004';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  Future<void> openLicenses(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      extraOverrides: [
        licenseCatalogProvider.overrideWith(
          (ref) => LicenseCatalog.fromRegistry(
            Stream.fromIterable([
              const LicenseEntryWithLineBreaks(['keykey'], _gpl),
              const LicenseEntryWithLineBreaks(['libsodium'], _isc),
              const LicenseEntryWithLineBreaks(['sodium'], _bsd3),
              const LicenseEntryWithLineBreaks(['flutter'], _bsd3),
              const LicenseEntryWithLineBreaks(['async'], _bsd3),
              const LicenseEntryWithLineBreaks(['Android libraries'], _apache),
              const LicenseEntryWithLineBreaks(['-'], 'Bozuk başlıklı metin'),
            ]),
          ),
        ),
      ],
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lisanslar'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lisanslar'));
    await tester.pumpAndSettle();
  }

  testWidgets('kendi sayfası: Ayarlar arkada görünmez, alt menü yok', (
    tester,
  ) async {
    await openLicenses(tester);
    expect(find.byKey(GlassNavBar.pillKey), findsNothing);
    expect(find.text('Şimdi kilitle'), findsNothing);
    // Uygulamanın kendi zemini; Flutter'ın hazır sayfası değil.
    expect(find.byType(LicensePage), findsNothing);
    expect(find.byType(KkBackdrop), findsWidgets);
  });

  testWidgets('önce KeyKey: lisansı, telif ve garanti olmadığı', (
    tester,
  ) async {
    await openLicenses(tester);
    expect(find.textContaining('GPL-3.0'), findsWidgets);
    expect(find.textContaining('garanti'), findsWidgets);
    expect(find.text('© 2026 KeyKey geliştiricileri'), findsOneWidget);

    await tester.tap(find.text('Lisans metnini oku'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GNU GENERAL PUBLIC LICENSE'), findsOneWidget);
  });

  testWidgets('kullanılan parçalar ne işe yaradığıyla, yalnızca var olanlar', (
    tester,
  ) async {
    await openLicenses(tester);
    expect(find.text('libsodium'), findsOneWidget);
    expect(find.text('Şifreleme · BSD-3-Clause, ISC'), findsOneWidget);
    expect(find.text('Android kütüphaneleri'), findsOneWidget);
    // Katalogda olmayan yazı tipi gösterilmez.
    expect(find.text('Barlow Condensed'), findsNothing);

    await tester.tap(find.text('libsodium'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ISC License'), findsOneWidget);
    expect(find.textContaining('Redistribution and use'), findsOneWidget);
    // İki paketin metni ayrı başlıklarla.
    expect(find.text('sodium'), findsOneWidget);
  });

  testWidgets('bütün paketler harf sırasında, türüyle; adsızlar sonda', (
    tester,
  ) async {
    // Liste tembel kurulur; hepsi görünsün diye uzun ekran.
    tester.view
      ..physicalSize = const Size(400, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openLicenses(tester);
    await tester.scrollUntilVisible(find.text('Bütün paketler'), 300);
    await tester.pumpAndSettle();
    expect(find.text('7 paket ve bileşen'), findsOneWidget);
    await tester.tap(find.text('Bütün paketler'));
    await tester.pumpAndSettle();

    final names = [
      'Android libraries',
      'async',
      'flutter',
      'keykey',
      'libsodium',
      'sodium',
      'Adı belirtilmemiş metinler',
    ];
    final tops = [
      for (final name in names) tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.text('Apache-2.0'), findsOneWidget);
    expect(find.text('Diğer lisans'), findsOneWidget);

    await tester.tap(find.text('Adı belirtilmemiş metinler'));
    await tester.pumpAndSettle();
    expect(find.text('Bozuk başlıklı metin'), findsOneWidget);
  });
}
