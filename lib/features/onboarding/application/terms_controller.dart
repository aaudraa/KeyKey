import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/onboarding/data/terms_acceptance.dart';

/// Kabulü saklayan depo. `bootstrap` dosyalı depoyu verir; testlerde
/// hiçbir şey yazılmaz.
final termsAcceptanceStoreProvider = Provider<TermsAcceptanceStore>(
  (ref) => const _NoTermsAcceptanceStore(),
);

/// Açılışta dosyadan okunan durum. `bootstrap` gerçek değeri verir;
/// varsayılan "kabul edilmiş", koşul ekranını sınamayan testler kasa
/// ekranlarından başlasın diye.
final initialTermsAcceptedProvider = Provider<bool>((ref) => true);

/// Kullanıcı güncel kullanım koşullarını kabul etti mi.
final termsAcceptedProvider = NotifierProvider<TermsController, bool>(
  TermsController.new,
);

class TermsController extends Notifier<bool> {
  @override
  bool build() => ref.read(initialTermsAcceptedProvider);

  /// Kabulü hemen geçerli kılar, sonra saklar. Dosyaya yazılamazsa kabul bu
  /// oturumda geçerlidir; bir sonraki açılışta koşullar yeniden sorulur.
  Future<void> accept() async {
    state = true;
    try {
      await ref.read(termsAcceptanceStoreProvider).write(currentTermsVersion);
    } on Exception {
      // Yeniden sorulması zarar vermez.
    }
  }
}

final class _NoTermsAcceptanceStore implements TermsAcceptanceStore {
  const new();

  @override
  Future<void> write(int version) async {}
}
