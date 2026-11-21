import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/app_packages.dart';
import 'package:keykey/core/platform/platform_api.g.dart';

final class _Api extends AppPackagesApi {
  new(this.model);

  final String model;

  @override
  Future<String> deviceModel() async => model;
}

void main() {
  test('telefon modeli 64 karakterde kesiliyor', () async {
    expect(await PigeonAppPackages(_Api('SM-G780G')).deviceModel(), 'SM-G780G');
    expect(
      await PigeonAppPackages(_Api('x' * 80)).deviceModel(),
      'x' * AppPackages.maxDeviceModelLength,
    );
    expect(
      await PigeonAppPackages(_Api('  Pixel 8  ')).deviceModel(),
      'Pixel 8',
    );
  });

  test('model bilinmeyen telefonda boş', () async {
    expect(await const NoAppPackages().deviceModel(), '');
  });
}
