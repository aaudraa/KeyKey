import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Donanım klavyesinin kopyala ve kes kısayollarını hassas panoya yönlendirir.
///
/// Flutter'ın metin kutusu Ctrl+C ve Ctrl+X'te panoya doğrudan yazar: süre
/// dolunca silinmez, hassas işareti taşımaz, klavyenin pano geçmişine düşer.
/// Bu kısayollar kutudan önce burada yakalanır (#173, S4).
class SensitiveCopyShortcuts extends StatelessWidget {
  const new({required this.onCopy, required this.child, this.onCut, super.key});

  final VoidCallback onCopy;

  /// Verilmezse kesme kısayolu metin kutusuna bırakılır (salt okunur metin).
  final VoidCallback? onCut;
  final Widget child;

  static const _copyKeys = [
    SingleActivator(LogicalKeyboardKey.keyC, control: true),
    SingleActivator(LogicalKeyboardKey.keyC, meta: true),
    SingleActivator(LogicalKeyboardKey.insert, control: true),
    SingleActivator(LogicalKeyboardKey.copy),
  ];

  static const _cutKeys = [
    SingleActivator(LogicalKeyboardKey.keyX, control: true),
    SingleActivator(LogicalKeyboardKey.keyX, meta: true),
    SingleActivator(LogicalKeyboardKey.delete, shift: true),
    SingleActivator(LogicalKeyboardKey.cut),
  ];

  @override
  Widget build(BuildContext context) {
    final onCut = this.onCut;
    return Shortcuts(
      shortcuts: {
        for (final key in _copyKeys) key: const _SensitiveCopyIntent(),
        if (onCut != null)
          for (final key in _cutKeys) key: const _SensitiveCutIntent(),
      },
      child: Actions(
        actions: {
          _SensitiveCopyIntent: CallbackAction<_SensitiveCopyIntent>(
            onInvoke: (_) {
              onCopy();
              return null;
            },
          ),
          if (onCut != null)
            _SensitiveCutIntent: CallbackAction<_SensitiveCutIntent>(
              onInvoke: (_) {
                onCut();
                return null;
              },
            ),
        },
        child: child,
      ),
    );
  }
}

class _SensitiveCopyIntent extends Intent {
  const new();
}

class _SensitiveCutIntent extends Intent {
  const new();
}
