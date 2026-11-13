import 'package:flutter/material.dart';
import 'package:keykey/app/theme.dart';

/// KeyKey'in logosu: kutusuz, kalın turuncu K.
///
/// Uygulama simgesi (`resources/design/keykey-simge.svg`) aynı yolu beyaz
/// daire içinde kullanır; yolun aynı kaldığını bir test denetler.
class KeyKeyLogo extends StatelessWidget {
  const new({this.size = 96, super.key});

  /// K'nın yolu, 100×100 kutuda.
  static const String pathData =
      'M24 14h16v30l28-30h20L57 47l33 39H69L46 58l-6 6v22H24z';

  /// K'nın rengi.
  static const Color color = KkColors.brandOrange;

  final double size;

  /// K'nın ölçeği: yüksekliği (72) kutunun %90'ı.
  static const double _scale = 0.9 * 100 / 72;

  /// Kutunun ortasına gelen nokta: K'nın sınır kutusunun ortası.
  static const Offset _center = Offset(57, 50);

  /// 100×100 kutuya ortalanmış K.
  static Path logoPath() {
    final matrix = Matrix4.identity()
      ..translateByDouble(50, 50, 0, 1)
      ..scaleByDouble(_scale, _scale, 1, 1)
      ..translateByDouble(-_center.dx, -_center.dy, 0, 1);
    return parsePath(pathData).transform(matrix.storage);
  }

  /// [pathData] gibi bir SVG yolunu çizer. Yalnızca `M h v l H L z`
  /// komutları desteklenir; başka bir komut [FormatException] verir.
  static Path parsePath(String data) {
    final tokens = RegExp(r'[A-Za-z]|-?\d+(?:\.\d+)?')
        .allMatches(data)
        .map((m) => m.group(0)!)
        .toList();
    final path = Path();
    var x = 0.0;
    var y = 0.0;
    var i = 0;
    double next() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      final command = tokens[i++];
      switch (command) {
        case 'M':
          x = next();
          y = next();
          path.moveTo(x, y);
        case 'L':
          x = next();
          y = next();
          path.lineTo(x, y);
        case 'l':
          x += next();
          y += next();
          path.lineTo(x, y);
        case 'H':
          x = next();
          path.lineTo(x, y);
        case 'h':
          x += next();
          path.lineTo(x, y);
        case 'V':
          y = next();
          path.lineTo(x, y);
        case 'v':
          y += next();
          path.lineTo(x, y);
        case 'z' || 'Z':
          path.close();
        default:
          throw FormatException('Desteklenmeyen yol komutu', command);
      }
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'KeyKey',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter()),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  static final Path _path = KeyKeyLogo.logoPath();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas
      ..save()
      ..scale(scale)
      ..drawPath(_path, Paint()..color = KeyKeyLogo.color)
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
