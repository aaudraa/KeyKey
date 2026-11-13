import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Son kaydedilen kaydın anahtarı (madde 2.2): form kapanınca listede o
/// kart bir kez parlar. Kart okuyunca temizlenir. Anahtarlar türle başlar
/// ([savedLoginKey], [savedOtpKey]); parola ve 2FA kimlikleri karışmaz.
final lastSavedProvider = NotifierProvider<LastSaved, String?>(LastSaved.new);

String savedLoginKey(String idHex) => 'login:$idHex';
String savedOtpKey(String idHex) => 'otp:$idHex';

class LastSaved extends Notifier<String?> {
  @override
  String? build() => null;

  // Riverpod'da durum yöntemle değişir; ayarlayıcı (setter) gerekmez.
  // ignore: use_setters_to_change_properties
  void mark(String key) => state = key;

  /// Anahtar hâlâ [key] ise temizler.
  void take(String key) {
    if (state == key) state = null;
  }
}

/// Liste kartı için: [key] son kaydedilense `true` döner ve anahtar kare
/// bittikten sonra temizlenir (kart parlamayı kendisi hatırlar).
bool watchLastSaved(WidgetRef ref, String key) {
  final hit = ref.watch(lastSavedProvider.select((saved) => saved == key));
  if (hit) {
    final notifier = ref.read(lastSavedProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => notifier.take(key));
  }
  return hit;
}
