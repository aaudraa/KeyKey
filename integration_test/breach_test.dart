import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/core/network/pwned_passwords_client.dart';
import 'package:keykey/features/vault/application/breach_check.dart';
import 'package:keykey/features/vault/data/login_content.dart';

import '../test/support/fake_vault_service.dart';

// Sızıntı kontrolünü gerçek ağda, sistemin güvendiği sertifikalarla
// doğrular. Cihazın internete çıkabilmesi gerekir.
//
// Şifresiz HTTP burada denenmez: Flutter, Android'in şifresiz trafik
// yasağını Dart'ın HttpClient'ına uygulamıyor (domainNetworkPolicy boş).
// https dışı adresi istemcinin kendisi reddeder; bkz.
// test/core/network/pwned_passwords_client_test.dart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test("Have I Been Pwned 'password'ü tanıyor", () async {
    final result = await BreachChecker(PwnedPasswordsClient()).check([
      FakeLoginRepository.item(
        const LoginContent(name: 'Deneme', password: 'password'),
        id: 1,
      ),
      FakeLoginRepository.item(
        const LoginContent(
          name: 'Rastgele',
          password: 'Vq7#kL2m!xR9pZ4wTe-2026',
        ),
        id: 2,
      ),
    ]);

    expect(result.countFor('password'), greaterThan(1000000));
    expect(result.countFor('Vq7#kL2m!xR9pZ4wTe-2026'), 0);
  });
}
