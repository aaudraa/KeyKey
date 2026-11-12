import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/features/vault/data/login_content.dart';

/// Kaydın baş harfi: kırpılmış adın ilk karakter kümesi (emoji yarım
/// kalmaz), büyük harf. Ad boşsa `?`.
String avatarInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

/// Addan türetilen kutu rengi: aynı ad hep aynı rengi alır. Kırpılmış ve
/// küçük harfe çevrilmiş adın FNV-1a (32 bit) özeti renk takımında sıra
/// seçer.
Color avatarColorFor(String name) {
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode(name.trim().toLowerCase())) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return KkColors.avatarPalette[hash % KkColors.avatarPalette.length];
}

/// Kaydın solundaki renkli kutu. Kayıt telefondaki bir uygulamaya bağlıysa o
/// uygulamanın simgesi (Android'den o an okunur, diske yazılmaz), değilse
/// addan renk alan kutuda baş harf. Süstür; ekran okuyucu okumaz.
class RecordAvatar extends ConsumerWidget {
  const new({
    required this.login,
    required this.name,
    this.size = 42,
    super.key,
  });

  final LoginContent? login;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final login = this.login;
    final packageName = (login == null || login.apps.isEmpty)
        ? null
        : login.apps.first.packageName;
    final icon = packageName == null
        ? null
        : ref.watch(appIconProvider(packageName)).value;
    final radius = BorderRadius.circular(size * 13 / 42);

    final Widget child;
    if (icon != null) {
      child = ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          icon,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      );
    } else {
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: avatarColorFor(name),
          borderRadius: radius,
        ),
        child: Center(
          child: Text(
            avatarInitial(name),
            maxLines: 1,
            // Kutu sabit boyda; büyük yazıda harf kutudan taşmasın.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}
