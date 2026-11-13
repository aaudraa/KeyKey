import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/features/vault/data/login_content.dart';

/// Kaydın baş harfi: kırpılmış adın ilk karakter kümesi (emoji yarım
/// kalmaz), büyük harf. Ad boşsa `?`.
String avatarInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

/// Kaydın solundaki simge. Kayıt telefondaki bir uygulamaya bağlıysa o
/// uygulamanın simgesi, kutusuz ve siyah-beyaz (Android'den o an okunur,
/// diske yazılmaz); değilse ince çizgili dairede baş harf. Süstür; ekran
/// okuyucu okumaz.
class RecordAvatar extends ConsumerWidget {
  const new({
    required this.login,
    required this.name,
    this.size = 34,
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
    final ink = Theme.of(context).colorScheme.onSurface;

    final Widget child;
    if (icon != null) {
      child = ColorFiltered(
        colorFilter: kkSaturation(0),
        child: Image.memory(
          icon,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      );
    } else {
      child = DecoratedBox(
        decoration: ShapeDecoration(
          shape: CircleBorder(side: BorderSide(color: ink, width: 1.2)),
        ),
        child: Center(
          child: Text(
            avatarInitial(name),
            maxLines: 1,
            // Kutu sabit boyda; büyük yazıda harf kutudan taşmasın.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: ink,
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
