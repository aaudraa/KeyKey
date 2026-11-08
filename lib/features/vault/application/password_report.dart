import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/password_policy.dart';
import 'package:keykey/features/generator/data/wordlists.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Zayıf parolalı bir kayıt.
final class WeakLogin {
  const new(this.item, this.strength);

  final LoginItem item;

  /// [PasswordStrength.tooShort] ya da [PasswordStrength.weak].
  final PasswordStrength strength;
}

/// Zayıf ve birden çok kayıtta kullanılan parolalar.
///
/// İnternete çıkmadan, yalnızca kasadaki kayıtlardan hesaplanır. Parola
/// değerlerini taşımaz, yalnızca kayıtları; ekranda parola gösterilmez.
final class PasswordReport {
  const new({required this.weak, required this.reused});

  /// Çöp kutusundaki ve parolası boş kayıtlar sayılmaz. Güç, kayıt
  /// düzenleme ekranındaki göstergeyle aynı kuralla ölçülür; "çok kısa" ve
  /// "zayıf" olanlar rapora girer.
  factory fromLogins(
    Iterable<LoginItem> items, {
    Set<String> common = const {},
  }) {
    final active = items
        .where(
          (item) => !item.content.isTrashed && item.content.password.isNotEmpty,
        )
        .toList();

    final weak = <WeakLogin>[];
    final byPassword = <String, List<LoginItem>>{};
    for (final item in active) {
      final password = item.content.password;
      final strength = PasswordPolicy.strengthOf(password, common: common);
      if (strength == PasswordStrength.tooShort ||
          strength == PasswordStrength.weak) {
        weak.add(WeakLogin(item, strength));
      }
      (byPassword[password] ??= []).add(item);
    }

    weak.sort((a, b) => _compareNames(a.item, b.item));
    final reused =
        [
          for (final group in byPassword.values)
            if (group.length > 1) group..sort(_compareNames),
        ]..sort((a, b) {
          final bySize = b.length.compareTo(a.length);
          return bySize != 0 ? bySize : _compareNames(a.first, b.first);
        });
    return PasswordReport(weak: weak, reused: reused);
  }

  /// Ada göre sıralı.
  final List<WeakLogin> weak;

  /// Aynı parolayı kullanan kayıt grupları; büyük grup önce, her grup ada
  /// göre sıralı. Her grupta en az iki kayıt var.
  final List<List<LoginItem>> reused;

  bool get isClean => weak.isEmpty && reused.isEmpty;

  static int _compareNames(LoginItem a, LoginItem b) =>
      foldForSearch(a.content.name).compareTo(foldForSearch(b.content.name));
}

/// Açık kasanın parola raporu. Kasa kilitliyken, kayıtlar ya da yaygın
/// parola listesi yüklenirken `null`.
///
/// Yalnızca bellekte tutulur: rapor ekranı kapanınca atılır, kilitte kayıtlarla
/// birlikte gider. Kasaya ve diske yazılmaz.
final Provider<PasswordReport?> passwordReportProvider =
    Provider.autoDispose<PasswordReport?>((ref) {
      final logins = ref.watch(loginsControllerProvider);
      final common = ref.watch(commonPasswordsProvider).value;
      if (logins is! LoginsLoaded || common == null) return null;
      return PasswordReport.fromLogins(logins.items, common: common);
    });
