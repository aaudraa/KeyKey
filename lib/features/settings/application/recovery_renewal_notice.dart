import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yeni kurtarma anahtarı doğrulanmadan kasa kilitlendi: kullanıcının not
/// aldığı anahtar geçersiz, eskisi hâlâ geçerli. Ayarlar ekranı kilit
/// açılınca bunu bir kez söyler. Yalnızca bellekte tutulur.
final recoveryRenewalInterruptedProvider =
    NotifierProvider<RecoveryRenewalInterrupted, bool>(
      RecoveryRenewalInterrupted.new,
    );

class RecoveryRenewalInterrupted extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;

  /// İşaretliyse `true` döner ve işareti kaldırır.
  bool take() {
    final marked = state;
    state = false;
    return marked;
  }
}
