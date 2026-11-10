import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/features/vault/data/login_content.dart';

/// Kartın kenarındaki silik resim: kayıt telefondaki bir uygulamaya
/// bağlıysa o uygulamanın simgesi, değilse renksiz çizgi simge (sitesi
/// varsa küre, yoksa anahtar). Görünürlüğü kartın kendisi ayarlar.
class RecordWatermark extends ConsumerWidget {
  const new({required this.login, this.size = 64, super.key});

  final LoginContent? login;
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
    if (icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.memory(
          icon,
          width: size,
          height: size,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      );
    }
    final hasSite = login != null && login.urls.isNotEmpty;
    return Icon(
      hasSite ? Icons.language_outlined : Icons.key_outlined,
      size: size * 0.6,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}
