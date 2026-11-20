import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/network/pwned_passwords_client.dart';
import 'package:keykey/features/vault/application/breach_check.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';

/// Parola raporundaki sızıntı kontrolünün durumu.
sealed class BreachCheckState {
  const new();
}

/// Henüz denetlenmedi; ağa hiç çıkılmadı.
final class BreachIdle extends BreachCheckState {
  const new();
}

/// Denetleniyor: [done] / [total] önek.
final class BreachRunning extends BreachCheckState {
  const new(this.done, this.total);

  final int done;
  final int total;
}

/// Denetim bitti. Sonuç yalnızca bellekte.
final class BreachDone extends BreachCheckState {
  const new(this.result);

  final BreachResult result;
}

/// Denetlenemedi (bağlantı yok, zaman aşımı, geçersiz yanıt). Yarım sonuç
/// tutulmaz.
final class BreachFailed extends BreachCheckState {
  const new();
}

/// Rapor ekranıyla yaşar: ekran kapanınca ya da kasa kilitlenince denetim
/// bırakılır, sonuç atılır. Kasaya, ayarlara ve diske hiçbir şey yazılmaz.
final NotifierProvider<BreachCheckController, BreachCheckState>
breachCheckProvider =
    NotifierProvider.autoDispose<BreachCheckController, BreachCheckState>(
      BreachCheckController.new,
    );

class BreachCheckController extends Notifier<BreachCheckState> {
  /// Her denetimin numarası; değişince süren denetim bırakılır.
  int _run = 0;

  @override
  BreachCheckState build() {
    ref
      ..onDispose(() => _run++)
      ..listen(loginsControllerProvider, (previous, next) {
        if (next is! LoginsLoaded) {
          _run++;
          state = const BreachIdle();
        }
      });
    return const BreachIdle();
  }

  /// Kullanıcının dokunuşuyla başlar; ağa yalnızca buradan çıkılır.
  Future<void> start() async {
    final logins = ref.read(loginsControllerProvider);
    if (logins is! LoginsLoaded || state is BreachRunning) return;
    final run = ++_run;
    bool cancelled() => run != _run || !ref.mounted;
    state = const BreachRunning(0, 0);
    try {
      final result = await BreachChecker(ref.read(pwnedRangeSourceProvider))
          .check(
            logins.items,
            onProgress: (done, total) {
              if (!cancelled()) state = BreachRunning(done, total);
            },
            isCancelled: cancelled,
          );
      if (!cancelled()) state = BreachDone(result);
    } on BreachCheckCancelled {
      // Ekran kapandı ya da kasa kilitlendi.
    } on Exception {
      if (!cancelled()) state = const BreachFailed();
    }
  }
}
