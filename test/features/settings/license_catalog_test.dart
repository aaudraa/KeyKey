import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/settings/data/license_catalog.dart';

const _mit =
    'Copyright (c) 2020 A\n\nPermission is hereby granted, free of charge, '
    'to any person obtaining a copy of this software';
const _bsd3 =
    'Redistribution and use in source and binary forms, with or without '
    'modification, are permitted\n\n* Neither the name of Google Inc. nor '
    'the names of its contributors may be used';
const _bsd2 =
    'Redistribution and use in source and binary forms, with or without '
    'modification, are permitted provided that the following conditions '
    'are met: 1. Redistributions of source code';
const _apache =
    'Apache License\nVersion 2.0, January 2004\n'
    'http://www.apache.org/licenses/';
const _isc =
    'ISC License\n\nPermission to use, copy, modify, and/or distribute this '
    'software for any purpose';
const _gpl = 'GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007';

void main() {
  group('licenseKindsOf', () {
    for (final (text, kind) in [
      (_mit, LicenseKind.mit),
      (_bsd3, LicenseKind.bsd3),
      (_bsd2, LicenseKind.bsd2),
      (_apache, LicenseKind.apache2),
      (_isc, LicenseKind.isc),
      (_gpl, LicenseKind.gpl3),
      (
        'This Source Code Form is subject to the terms of the Mozilla Public '
            'License, v. 2.0.',
        LicenseKind.mpl2,
      ),
      ('SIL OPEN FONT LICENSE Version 1.1', LicenseKind.ofl),
      (
        'Licensed under the Creative Commons Attribution 3.0 Unported '
            'License (CC BY 3.0)',
        LicenseKind.ccBy3,
      ),
      (
        'The SQLite source code is in the public domain.',
        LicenseKind.publicDomain,
      ),
      (
        "This software is provided 'as-is', without any express or implied "
            'warranty. Permission is granted to anyone to use this software '
            'for any purpose',
        LicenseKind.zlib,
      ),
    ]) {
      test('${kind.name} tanınır', () {
        expect(licenseKindsOf(text), {kind});
      });
    }

    test('tanınmayan metin "diğer"', () {
      expect(licenseKindsOf('Bu yazılımı dilediğin gibi kullan.'), {
        LicenseKind.other,
      });
    });

    test('lisansı uzun adıyla anan GPL olmayan metin GPL sayılmaz', () {
      // LGPL'nin ilk satırı GPL'yi de anar.
      expect(
        licenseKindsOf(
          'GNU LESSER GENERAL PUBLIC LICENSE\nVersion 3\nThis version of '
          'the GNU Lesser General Public License incorporates the terms of '
          'version 3 of the GNU General Public License',
        ),
        {LicenseKind.lgpl},
      );
    });

    test('OFL metnindeki MIT kalıbı MIT sayılmaz', () {
      // OFL 1.1 de "Permission is hereby granted, free of charge" der.
      expect(
        licenseKindsOf(
          'SIL OPEN FONT LICENSE Version 1.1\n\nPermission is hereby '
          'granted, free of charge, to any person obtaining a copy of the '
          'Font Software',
        ),
        {LicenseKind.ofl},
      );
    });

    test("GPL'nin sonunda LGPL'nin anılması GPL'yi değiştirmez", () {
      expect(
        licenseKindsOf(
          '$_gpl\n\n...consider it more useful to permit linking '
          'proprietary applications with the library. If this is what you '
          'want to do, use the GNU Lesser General Public License instead of '
          'this License.',
        ),
        {LicenseKind.gpl3},
      );
    });

    test("MPL'nin ikincil lisans olarak GPL'yi anması GPL sayılmaz", () {
      expect(
        licenseKindsOf(
          'Mozilla Public License Version 2.0\n\n1.12. "Secondary License" '
          'means either the GNU General Public License, Version 2.0, the GNU '
          'Lesser General Public License, Version 2.1',
        ),
        {LicenseKind.mpl2},
      );
    });

    test('Apache metnini anan MIT lisansı yalnızca MIT', () {
      expect(licenseKindsOf('$_mit\n\nUnlike the Apache License...'), {
        LicenseKind.mit,
      });
    });
  });

  group('LicenseCatalog', () {
    Stream<LicenseEntry> entries(List<(List<String>, String)> items) =>
        Stream.fromIterable([
          for (final (packages, text) in items)
            LicenseEntryWithLineBreaks(packages, text),
        ]);

    test('aynı paketin metinleri bir arada, türleri birleşik', () async {
      final catalog = await LicenseCatalog.fromRegistry(
        entries([
          (['sodium'], _bsd3),
          (['sodium', 'libsodium'], _isc),
        ]),
      );
      final sodium = catalog['sodium']!;
      expect(sodium.texts, hasLength(2));
      expect(sodium.kinds, {LicenseKind.bsd3, LicenseKind.isc});
      expect(catalog['libsodium']!.kinds, {LicenseKind.isc});
    });

    test('tanınan lisansın yanında "diğer" gösterilmez', () async {
      // Motorun telif satırları lisans gövdesi taşımaz.
      final catalog = await LicenseCatalog.fromRegistry(
        entries([
          (['flutter'], _bsd3),
          (['flutter'], 'Copyright 2014 The Chromium Authors.'),
          (['dawn'], 'Copyright 2017 The Dawn Authors.'),
        ]),
      );
      expect(catalog['flutter']!.kinds, {LicenseKind.bsd3});
      expect(catalog['flutter']!.texts, hasLength(2));
      expect(catalog['dawn']!.kinds, {LicenseKind.other});
    });

    test('paketler harf sırasında, büyük küçük harf ayrımı yok', () async {
      final catalog = await LicenseCatalog.fromRegistry(
        entries([
          (['zlib'], _mit),
          (['Barlow Condensed'], 'SIL OPEN FONT LICENSE'),
          (['async'], _bsd3),
        ]),
      );
      expect(catalog.packages.map((p) => p.name), [
        'async',
        'Barlow Condensed',
        'zlib',
      ]);
    });

    test('bozuk başlıklı metinler adsız grupta, kaybolmaz', () async {
      final catalog = await LicenseCatalog.fromRegistry(
        entries([
          (['-'], _mit),
          (['Copyright 2013 The Flutter Authors'], _bsd3),
          (['flutter'], _bsd3),
        ]),
      );
      expect(catalog.packages.map((p) => p.name), [
        'flutter',
        LicenseCatalog.unnamed,
      ]);
      expect(catalog[LicenseCatalog.unnamed]!.texts, hasLength(2));
    });

    test('girinti ve paragraflar metinde korunur', () async {
      final catalog = await LicenseCatalog.fromRegistry(
        Stream.value(
          const _Entry(
            ['a'],
            [
              LicenseParagraph('Birinci paragraf.', 0),
              LicenseParagraph('İkinci, girintili.', 1),
              LicenseParagraph(
                'Ortalanmış başlık',
                LicenseParagraph.centeredIndent,
              ),
            ],
          ),
        ),
      );
      expect(
        catalog['a']!.texts.single,
        'Birinci paragraf.\n\n  İkinci, girintili.\n\nOrtalanmış başlık',
      );
    });
  });
}

class _Entry extends LicenseEntry {
  const new(this.packages, this.paragraphs);

  @override
  final List<String> packages;

  @override
  final List<LicenseParagraph> paragraphs;
}
