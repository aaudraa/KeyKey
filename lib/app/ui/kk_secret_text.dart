import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Gizli değer (madde 3.1). Gizliyken uzunluğu belli etmeyen
/// [concealedLength] nokta görünür. Açılınca karakterler soldan sağa sırayla
/// noktaların yerine geçer (karakter başına [perChar], toplam en çok
/// [maxTotal]); gizlerken tersine. Animasyonlar kapalıyken anında.
///
/// Açıkken ekran okuyucu yalnızca tam değeri okur; gizliyken bir şey
/// söylemez, "gizli" etiketini çağıran verir.
class KkSecretText extends StatefulWidget {
  const new({
    required this.text,
    required this.revealed,
    this.style,
    super.key,
  });

  static const int concealedLength = 8;
  static const Duration perChar = KkMotion.secretPerChar;
  static const Duration maxTotal = KkMotion.secretMax;

  final String text;
  final bool revealed;
  final TextStyle? style;

  @override
  State<KkSecretText> createState() => _KkSecretTextState();
}

class _KkSecretTextState extends State<KkSecretText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    value: widget.revealed ? 1 : 0,
  );

  @override
  void didUpdateWidget(KkSecretText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealed == oldWidget.revealed) return;
    final length = widget.text.characters.length;
    final total = KkSecretText.perChar * length;
    _motion.duration = KkMotion.of(
      context,
      total > KkSecretText.maxTotal ? KkSecretText.maxTotal : total,
    );
    if (widget.revealed) {
      _motion.forward();
    } else {
      _motion.reverse();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  String _shown(double progress) {
    final chars = widget.text.characters.toList();
    // Kayan nokta payı: tam adım sınırında bir eksik sayılmasın.
    final open = (progress * chars.length + 1e-6).floor().clamp(
      0,
      chars.length,
    );
    if (open == 0) return '•' * KkSecretText.concealedLength;
    return chars.take(open).join() + '•' * (chars.length - open);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.revealed ? widget.text : null,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) =>
            Text(_shown(_motion.value), style: widget.style),
      ),
    );
  }
}
