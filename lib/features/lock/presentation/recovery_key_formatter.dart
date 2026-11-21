import 'package:keykey/app/grouped_text_formatter.dart';
import 'package:keykey/features/lock/application/recovery_key_text.dart';

/// Kurtarma anahtarını yazarken kağıttaki gibi gösterir: büyük harf ve beşli
/// gruplar arasında tire. Tireyi kullanıcı yazmaz, kendiliğinden gelir.
///
/// Alfabede olmayan I, L ve O harfleri yazılırken 1 ve 0'a çevrilir; çözücü de
/// onları öyle okur. Böylece ekrandaki metin kağıttakiyle birebir
/// karşılaştırılabilir.
class RecoveryKeyFormatter extends GroupedTextFormatter {
  new()
    : super(
        groupLength: RecoveryKeyText.groupLength,
        separator: '-',
        allowed: RegExp(r'^[A-Za-z0-9ıİ \t-]*$'),
        normalize: RecoveryKeyText.normalize,
      );
}
