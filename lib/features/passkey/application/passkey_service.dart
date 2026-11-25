import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/network/asset_links_client.dart';
import 'package:keykey/features/autofill/application/autofill_matches.dart';
import 'package:keykey/features/passkey/application/passkey_bridge.dart';
import 'package:keykey/features/passkey/domain/passkey_caller.dart';
import 'package:keykey/features/passkey/domain/passkey_plan.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// İstek, kasaya bakmadan çözülmüş hali. Kurala uymayan istek
/// [PasskeyRequestException] hatasıyla biter; pencere bunu kilit
/// açtırmadan söyler.
final passkeyPromptProvider = FutureProvider<PasskeyPrompt?>((ref) async {
  final request = await ref.watch(passkeyRequestProvider.future);
  if (request == null) return null;
  return resolvePasskeyPrompt(
    create: request.kind == PasskeyRequestKind.create,
    requestJson: request.requestJson,
    caller: request.caller,
    suffixes: await ref.watch(publicSuffixListProvider.future),
    clientDataHash: request.clientDataHash,
  );
});

/// Çağıran `rpId`'nin sitesine ait mi. Güvenilen tarayıcıda her zaman
/// evet; uygulamada otomatik doldurmadaki doğrulanmış site kuralı. İnternet
/// ayarı kasada olduğu için kasa açıkken okunur.
final passkeyAppVerifiedProvider = FutureProvider<bool>((ref) async {
  final prompt = await ref.watch(passkeyPromptProvider.future);
  if (prompt == null) return false;
  if (prompt.caller.isBrowser) return true;
  final bridge = ref.watch(passkeyBridgeProvider);
  try {
    return await appBelongsToRp(
      caller: prompt.caller,
      rpId: prompt.rpId,
      domains: await bridge.appDomains(prompt.caller.packageName),
      verifyOnline: await verifySitesOnlineEnabled(ref),
      source: ref.read(assetLinksSourceProvider),
      hasSigningCertificates: bridge.hasSigningCertificates,
      suffixes: await ref.read(publicSuffixListProvider.future),
    );
  } on Exception {
    return false;
  }
});

/// Kayıtlar okunamadı; pencere yeniden denetir.
final class PasskeyLoadFailed implements Exception {
  const new();
}

/// Açık kasadaki, isteğe uyan kayıtlar. Kasa yüklenirken `null`.
final class PasskeyCandidates {
  const new({required this.targets, required this.passkeys});

  /// Oluşturmada passkey'in eklenebileceği kayıtlar.
  final List<LoginItem> targets;

  /// Girişte kullanılabilecek passkey'ler.
  final List<(LoginItem, LoginPasskey)> passkeys;
}

final passkeyCandidatesProvider = FutureProvider<PasskeyCandidates?>((
  ref,
) async {
  final prompt = await ref.watch(passkeyPromptProvider.future);
  final logins = ref.watch(loginsControllerProvider);
  if (prompt == null) return null;
  if (logins is LoginsFailed) throw const PasskeyLoadFailed();
  if (logins is! LoginsLoaded) return null;
  final creation = prompt.creation;
  if (creation != null) {
    if (alreadyRegistered(
      logins.items,
      prompt.rpId,
      creation.excludeCredentialIds,
    )) {
      throw const PasskeyRequestException(PasskeyError.alreadyExists);
    }
    return PasskeyCandidates(
      targets: createTargets(
        items: logins.items,
        rpId: prompt.rpId,
        userName: creation.userName,
        suffixes: await ref.read(publicSuffixListProvider.future),
      ),
      passkeys: const [],
    );
  }
  return PasskeyCandidates(
    targets: const [],
    passkeys: passkeysFor(
      items: logins.items,
      rpId: prompt.rpId,
      allowIds: prompt.assertion!.allowCredentialIds,
    ),
  );
});

final passkeyServiceProvider = Provider<PasskeyService>(PasskeyService.new);

/// Passkey oluşturma ve giriş yanıtları. Özel anahtar Dart'tan yalnızca
/// imza çağrısı süresince çıkar.
final class PasskeyService {
  const new(this._ref);

  final Ref _ref;

  /// Anahtar üretir, passkey'i [target] kaydına ya da yeni bir kayda yazar
  /// ve `RegistrationResponseJSON` döner. Uygulama siteye ait olduğu
  /// doğrulandıysa ([bindApp]) kayda bağlanır.
  Future<String> create({
    required PasskeyPrompt prompt,
    required LoginItem? target,
    required bool bindApp,
  }) async {
    final options = prompt.creation!;
    final pair = await _ref.read(passkeyKeysProvider).generate();
    final credentialId = newCredentialId();
    final passkey = LoginPasskey(
      credentialId: credentialId,
      rpId: prompt.rpId,
      userHandle: options.userId,
      userName: options.userName,
      userDisplayName: options.userDisplayName,
      privateKey: pair.privateKey,
      createdAt: DateTime.now().toUtc(),
    );
    final app = bindApp ? _app(prompt.caller) : null;
    final controller = _ref.read(loginsControllerProvider.notifier);
    if (target == null) {
      await controller.add(
        newPasskeyLogin(
          options: options,
          rpId: prompt.rpId,
          passkey: passkey,
          app: app,
        ),
      );
    } else {
      await controller.changePasskeys(
        target,
        (content) => withPasskey(content, passkey, app: app),
      );
    }
    return registrationResponse(
      options: options,
      rpId: prompt.rpId,
      credentialId: credentialId,
      publicX: pair.x,
      publicY: pair.y,
      origin: prompt.origin,
    );
  }

  /// Her passkey için imzalı giriş yanıtı. İmza atılamayan passkey (bozuk
  /// içe aktarılmış anahtar gibi) atlanır, diğerleri yine verilir; hiçbirine
  /// imza atılamazsa ilk hata fırlatılır.
  Future<List<PasskeyAssertion>> assertions({
    required PasskeyPrompt prompt,
    required List<(LoginItem, LoginPasskey)> passkeys,
  }) async {
    final keys = _ref.read(passkeyKeysProvider);
    final result = <PasskeyAssertion>[];
    Exception? firstError;
    for (final (item, passkey) in passkeys) {
      try {
        result.add(
          PasskeyAssertion(
            credentialId: passkey.credentialIdB64,
            userName: passkeyAccountName(passkey, item),
            displayName: passkey.userDisplayName,
            responseJson: await assertionResponse(
              options: prompt.assertion!,
              rpId: prompt.rpId,
              passkey: passkey,
              origin: prompt.origin,
              clientDataHash: prompt.clientDataHash,
              sign: keys.sign,
            ),
          ),
        );
      } on Exception catch (error) {
        firstError ??= error;
      }
    }
    if (result.isEmpty && firstError != null) throw firstError;
    return result;
  }

  LoginApp? _app(PasskeyCaller caller) {
    if (caller.isBrowser ||
        caller.certsSha256.isEmpty ||
        !LoginApp.isValidPackageName(caller.packageName) ||
        !caller.certsSha256.every(LoginApp.isValidCertDigest)) {
      return null;
    }
    return LoginApp(
      packageName: caller.packageName,
      certsSha256: caller.certsSha256,
    );
  }
}
