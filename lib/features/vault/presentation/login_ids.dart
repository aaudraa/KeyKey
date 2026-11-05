import 'dart:typed_data';

import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Kayıt kimliğinin adres satırındaki hali. Kimlik rastgeledir, içerik
/// hakkında bilgi vermez.
String loginIdHex(Uint8List id) =>
    id.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

/// Yüklenmiş kayıtlarda kimliği arar. Kayıt silinmişse `null` döner.
LoginItem? findLogin(LoginsState state, String idHex) {
  if (state is! LoginsLoaded) return null;
  for (final item in state.items) {
    if (loginIdHex(item.id) == idHex) return item;
  }
  return null;
}
