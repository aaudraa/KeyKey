import 'dart:async';

import 'package:keykey/core/network/pwned_passwords_client.dart';

/// Have I Been Pwned yerine geçen sahte kaynak; sorulan önekleri kaydeder.
class FakeRangeSource implements PwnedRangeSource {
  new([this.answer]);

  /// Önek için yanıt; `null` ise yalnızca dolgu satırı.
  FutureOr<String> Function(String prefix)? answer;

  final calls = <String>[];

  @override
  Future<String> fetchRange(String prefix) async {
    calls.add(prefix);
    return await answer?.call(prefix) ?? '$pwnedPadding:0\r\n';
  }
}

/// Dolgu satırının soneki; sayısı her zaman 0.
const pwnedPadding = '00000000000000000000000000000000000';
