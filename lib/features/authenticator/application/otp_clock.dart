import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kodların hesaplandığı saat. Testler sabit bir saat verir.
final otpClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
