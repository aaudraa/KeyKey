import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Ekranın giriş hareketinin kapsamı (madde 1.1 ve 1.10).
///
/// - Kapsamın ilk karesinde kurulan [KkEntrance]'lar sırayla belirir.
/// - Kaydırırken ekrana giren öğe de, sıra gecikmesi olmadan, belirir.
/// - Sekmeye dönünce (`TickerMode` yeniden açılınca) ve üstteki alt ekran
///   kapanmaya başlayınca görünen öğeler girişi yeniden oynar.
class KkEntranceScope extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<KkEntranceScope> createState() => _KkEntranceScopeState();
}

class _KkEntranceScopeState extends State<KkEntranceScope> {
  final _gate = _EntranceGate();

  /// Her yeniden oynamada bir artar.
  final _replay = ValueNotifier<int>(0);

  ValueListenable<TickerModeData>? _ticker;
  bool _tickerWasOn = true;
  Animation<double>? _cover;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _gate.open = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ticker = TickerMode.getValuesNotifier(context);
    if (ticker != _ticker) {
      _ticker?.removeListener(_onTicker);
      _ticker = ticker..addListener(_onTicker);
      _tickerWasOn = ticker.value.enabled;
    }
    final cover = ModalRoute.of(context)?.secondaryAnimation;
    if (cover != _cover) {
      _cover?.removeStatusListener(_onCover);
      _cover = cover?..addStatusListener(_onCover);
    }
  }

  void _onTicker() {
    final on = _ticker!.value.enabled;
    if (on && !_tickerWasOn) _replay.value++;
    _tickerWasOn = on;
  }

  /// Üstteki sayfa kapanmaya başladı: altındaki liste yeniden belirir.
  void _onCover(AnimationStatus status) {
    if (status == AnimationStatus.reverse) _replay.value++;
  }

  @override
  void dispose() {
    _ticker?.removeListener(_onTicker);
    _cover?.removeStatusListener(_onCover);
    _replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _EntranceInherited(gate: _gate, replay: _replay, child: widget.child);
}

class _EntranceGate {
  bool open = true;
}

class _EntranceInherited extends InheritedWidget {
  const new({required this.gate, required this.replay, required super.child});

  final _EntranceGate gate;
  final ValueListenable<int> replay;

  @override
  bool updateShouldNotify(_EntranceInherited old) => false;
}

/// Liste öğesi: saydamlık 0'dan 1'e, 16 dp aşağıdan ve %96 ölçekten yaylanarak
/// yerine ([KkMotion.enter]). İlk karedeki öğeler sırayla gelir; gecikme
/// sekizinci öğede durur. Kapsam dışındaki ya da animasyonlar kapalıyken
/// öğe hemen görünür.
class KkEntrance extends StatefulWidget {
  const new({required this.index, required this.child, super.key});

  static const Duration step = KkMotion.stagger;

  /// Gecikmenin büyüdüğü öğe sayısı.
  static const int maxStaggered = KkMotion.staggerMax;

  /// Başlangıçtaki aşağı kayma ve ölçek.
  static const double rise = 16;
  static const double startScale = 0.96;

  final int index;
  final Widget child;

  @override
  State<KkEntrance> createState() => _KkEntranceState();
}

class _KkEntranceState extends State<KkEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  _EntranceInherited? _scope;
  ScrollPosition? _position;
  bool _waitingToShow = false;

  Duration get _delay =>
      KkEntrance.step * math.min(widget.index, KkEntrance.maxStaggered);

  bool get _enabled => !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.getInheritedWidgetOfExactType<_EntranceInherited>();
    if (scope == _scope) return;
    final first = _scope == null;
    _scope?.replay.removeListener(_onReplay);
    _scope = scope?..replay.addListener(_onReplay);
    if (!first || scope == null || !_enabled) return;
    final skip = context
        .getInheritedWidgetOfExactType<KkEntranceSkipScope>()
        ?.skip
        .active;
    if (skip ?? false) {
      _controller.value = 1;
      return;
    }
    if (scope.gate.open) {
      _play(_delay);
    } else {
      _showWhenVisible();
    }
  }

  /// Hareketi baştan oynatır: önce [delay] boyunca gizli bekler.
  void _play(Duration delay) {
    final total = delay + KkMotion.enter;
    _controller
      ..duration = total
      ..value = 0;
    _startAt = delay.inMicroseconds / total.inMicroseconds;
    _controller.forward();
  }

  double _startAt = 0;

  /// Kaydırırken kurulan öğe: ekranda görünür olunca belirir. Önbellek
  /// alanında (ekranın dışında) kurulanlar o ana kadar gizli bekler.
  void _showWhenVisible() {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return;
    _controller.value = 0;
    _waitingToShow = true;
    _position = position..addListener(_checkVisible);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
  }

  void _checkVisible() {
    if (!_waitingToShow || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final Object? viewportBox = RenderAbstractViewport.maybeOf(box);
    if (viewportBox is! RenderBox) return;
    final top = box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final visible = top < viewportBox.size.height && top + box.size.height > 0;
    if (!visible) return;
    _stopWaiting();
    _play(Duration.zero);
  }

  void _stopWaiting() {
    _waitingToShow = false;
    _position?.removeListener(_checkVisible);
    _position = null;
  }

  void _onReplay() {
    if (!mounted || !_enabled || _waitingToShow) return;
    _play(_delay);
  }

  @override
  void dispose() {
    _stopWaiting();
    _scope?.replay.removeListener(_onReplay);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final raw = _controller.value;
        final t = raw <= _startAt || _startAt >= 1
            ? (raw >= 1 ? 1.0 : 0.0)
            : (raw - _startAt) / (1 - _startAt);
        final motion = KkMotion.spring.transform(t);
        final fade = KkMotion.standard.transform(math.min(1, t / 0.6));
        final scale =
            KkEntrance.startScale + (1 - KkEntrance.startScale) * motion;
        return Opacity(
          opacity: fade,
          // Ekranın altında görünmeyi bekleyen kart ekran okuyucudan
          // gizlenmesin; TalkBack sıradakine geçebilsin.
          alwaysIncludeSemantics: true,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(0, KkEntrance.rise * (1 - motion), 0, 1)
              ..scaleByDouble(scale, scale, 1, 1),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Giriş hareketini bir kerelik atlatan işaret: açıkken kurulan
/// [KkEntrance]'lar hemen görünür. Liste baştan kurulduğunda (sıralama,
/// büyük arama değişikliği) kartlar bir kare boşalıp yeniden girmesin diye.
class KkEntranceSkip {
  bool active = false;
}

/// [KkEntranceSkip]'i alttaki girişlere verir; değişince kimseyi yeniden
/// kurmaz, girişler yalnızca kurulurken bakar.
class KkEntranceSkipScope extends InheritedWidget {
  const new({required this.skip, required super.child, super.key});

  final KkEntranceSkip skip;

  @override
  bool updateShouldNotify(KkEntranceSkipScope oldWidget) =>
      skip != oldWidget.skip;
}
