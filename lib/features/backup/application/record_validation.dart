import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/record_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';

/// Çözülmüş bir kaydın içeriğini türüne göre doğrular; uymazsa
/// [InvalidBackupException]. Geri yükleme ve senkron, başka bir yerden gelen
/// kaydı kasaya yazmadan önce aynı kuralla denetler.
void validateRecordContent(String type, Uint8List plain) {
  try {
    switch (type) {
      case LoginRepository.recordType:
        LoginContent.fromJsonBytes(plain);
      case RecordCipher.otpType:
        OtpContent.fromJsonBytes(plain);
      case VaultRecordRepository.cardType:
        CardContent.fromJsonBytes(plain);
      case VaultRecordRepository.noteType:
        NoteContent.fromJsonBytes(plain);
      case SettingsRepository.recordType:
        if (AppSettings.tryParse(plain) == null) {
          throw const InvalidBackupException('Okunamayan ayar kaydı.');
        }
      default:
        throw const InvalidBackupException('Desteklenmeyen kayıt türü.');
    }
  } on InvalidLoginContentException {
    throw const InvalidBackupException('Okunamayan parola kaydı.');
  } on InvalidOtpContentException {
    throw const InvalidBackupException('Okunamayan 2FA kaydı.');
  } on InvalidRecordContentException {
    throw InvalidBackupException(
      type == VaultRecordRepository.noteType
          ? 'Okunamayan not kaydı.'
          : 'Okunamayan kart kaydı.',
    );
  }
}
