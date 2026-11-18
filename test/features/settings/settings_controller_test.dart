import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  test('otomatik yedek klasörü yazılıyor ve siliniyor', () async {
    final service = FakeVaultService(sodium);
    final repository = FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [
        vaultServiceProvider.overrideWithValue(service),
        initialVaultStatusProvider.overrideWithValue(
          VaultOpen(service.newSession()),
        ),
        settingsRepositoryFactoryProvider.overrideWithValue((_) => repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(settingsControllerProvider, (_, _) {});
    await pumpEventQueue();
    const folder = AutoBackupFolder(uri: 'content://x/tree/1', name: 'KeyKey');

    final controller = container.read(settingsControllerProvider.notifier);
    await controller.setAutoBackupFolder(folder);
    expect(
      container.read(settingsControllerProvider)?.autoBackupFolder?.uri,
      folder.uri,
    );
    expect(repository.settings.autoBackupFolder?.name, 'KeyKey');

    await controller.setAutoBackupFolder(null);
    expect(
      container.read(settingsControllerProvider)?.autoBackupFolder,
      isNull,
    );
    expect(repository.settings.autoBackupFolder, isNull);
  });
}
