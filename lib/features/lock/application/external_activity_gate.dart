import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';

/// KeyKey'in kendi açtığı bir sistem ekranı (dosya seçici, belge oluşturma,
/// fotoğraf seçici) sürerken arka plan kilidini erteler.
///
/// Bu ekranlar ayrı bir etkinlik olarak açılır ve uygulamayı arka plana
/// alır. Kilit ertelenmezse kullanıcı dosyayı seçip döndüğünde kasa kilitli
/// olur ve işlem sonuçsuz kalır. Erteleme en fazla [maxDuration] sürer; süre
/// dolunca kasa, ekran hâlâ açık olsa bile kilitlenir. Dokunmama kilidi bu
/// sırada da çalışır. Kurallar güvenlik tasarımı belgesinin "Otomatik kilit"
/// bölümündedir.
class ExternalActivityGate extends Notifier<bool> {
  static const maxDuration = Duration(minutes: 3);

  Timer? _deadline;

  @override
  bool build() {
    ref.onDispose(() => _deadline?.cancel());
    return false;
  }

  /// [action] sürerken arka plana geçmek kasayı kilitlemez.
  Future<T> run<T>(Future<T> Function() action) async {
    _deadline?.cancel();
    _deadline = Timer(maxDuration, () {
      state = false;
      ref.read(vaultControllerProvider.notifier).lock();
    });
    state = true;
    try {
      return await action();
    } finally {
      _deadline?.cancel();
      _deadline = null;
      state = false;
    }
  }
}

final externalActivityGateProvider =
    NotifierProvider<ExternalActivityGate, bool>(ExternalActivityGate.new);
