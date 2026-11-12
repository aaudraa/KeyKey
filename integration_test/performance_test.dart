import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// 1000 kayıtla yükleme, arama ve kaydırma süresi. Debug derlemesinde
/// ölçüldüğü için gerçek kullanımdan yavaştır.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1000 kayıtla liste ve arama', (tester) async {
    final support = await getApplicationSupportDirectory();
    final directory = support.createTempSync('performans_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final database = VaultDatabase.openFile(
      File('${directory.path}/keykey.db'),
    );
    addTearDown(database.close);
    final store = VaultStore(database);
    final sodium = await SodiumSumoInit.init();
    final service = VaultService(sodium: sodium, store: store);
    final pending = await service.prepareVault('dogru-Ana-Parola-47');
    final session = await service.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    final repository = LoginRepository(
      store: store,
      session: session,
      sodium: sodium,
    );
    for (var i = 0; i < 1000; i++) {
      await repository.add(
        LoginContent(
          name: 'Kayıt $i',
          username: 'kullanici$i@example.com',
          password: 'parola-$i',
          urls: ['https://site$i.example.com/giris'],
          folder: 'Klasör ${i % 10}',
        ),
      );
    }

    final load = Stopwatch()..start();
    final loaded = await repository.loadAll();
    load.stop();
    expect(loaded.items, hasLength(1000));

    final indexed = loaded.items.map(IndexedLogin.new).toList();
    final search = Stopwatch()..start();
    for (final query in ['kayıt 99', 'site5', 'klasör 3', 'yok']) {
      filterLogins(indexed, LoginFilter(query: query));
    }
    search.stop();

    tester.platformDispatcher.localesTestValue = [const Locale('tr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ambientMotionProvider.overrideWithValue(false),
          vaultServiceProvider.overrideWithValue(service),
          initialVaultStatusProvider.overrideWithValue(VaultOpen(session)),
          loginRepositoryFactoryProvider.overrideWithValue((_) => repository),
          settingsRepositoryFactoryProvider.overrideWithValue(
            (session) => SettingsRepository(store: store, session: session),
          ),
          otpRepositoryFactoryProvider.overrideWithValue(
            (session) =>
                OtpRepository(store: store, session: session, sodium: sodium),
          ),
        ],
        child: const KeyKeyApp(),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (find.text('Kayıt 0').evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) fail('Liste yüklenmedi');
      await tester.pump(const Duration(milliseconds: 100));
    }

    final scroll = Stopwatch()..start();
    for (var i = 0; i < 5; i++) {
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 4000);
      await tester.pumpAndSettle();
    }
    scroll.stop();

    final typing = Stopwatch()..start();
    await tester.enterText(
      find.widgetWithText(TextField, '1000 kayıtta ara'),
      'kayıt 999',
    );
    await tester.pump();
    typing.stop();
    expect(find.text('Kayıt 999'), findsOneWidget);

    // Betik bu satırı okuyor.
    // ignore: avoid_print
    print(
      'KKPERF yukleme_ms=${load.elapsedMilliseconds} '
      'dort_arama_ms=${search.elapsedMilliseconds} '
      'bes_kaydirma_ms=${scroll.elapsedMilliseconds} '
      'yazip_suzme_ms=${typing.elapsedMilliseconds}',
    );
    expect(load.elapsedMilliseconds, lessThan(3000));
    expect(search.elapsedMilliseconds, lessThan(200));

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
