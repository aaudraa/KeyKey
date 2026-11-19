import 'dart:convert';

import 'package:flutter/services.dart';

/// Metni UTF-8 bayt sınırında tutar: sınırı aşan değişiklik uygulanmaz.
///
/// `maxLength` karakter sayar; Türkçe harfler iki bayt olduğu için kayıt
/// sınırı (ör. 64 KiB not) bayt üzerinden denetlenir.
class Utf8LengthLimitingFormatter extends TextInputFormatter {
  const new(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    // Her UTF-16 birimi en çok 3 bayt olur; kısa metinde kodlamaya gerek yok.
    if (text.length * 3 <= maxBytes) return newValue;
    return utf8.encode(text).length <= maxBytes ? newValue : oldValue;
  }
}
