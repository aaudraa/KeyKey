import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';

const publicSuffixListPath = 'resources/assets/autofill/public_suffix_list.dat';

/// Gömülü Public Suffix List; yalnızca web hedefinde yüklenir.
final publicSuffixListProvider = FutureProvider<PublicSuffixList>((ref) async {
  return PublicSuffixList.parse(
    await rootBundle.loadString(publicSuffixListPath),
  );
});

/// Açık kasadaki kayıtların doldurulacak hedefle eşleşmesi.
final autofillMatchesProvider = FutureProvider<LoginMatches>((ref) async {
  final logins = ref.watch(loginsControllerProvider);
  final bridge = ref.watch(autofillBridgeProvider);
  final target = await ref.watch(autofillTargetProvider.future);
  if (target == null || logins is! LoginsLoaded) return LoginMatches.empty;
  final suffixes = target.isWeb
      ? await ref.read(publicSuffixListProvider.future)
      : null;
  return await matchLogins(
    target: target,
    items: logins.items,
    suffixes: suffixes,
    hasSigningCertificates: bridge.hasSigningCertificates,
  );
});
