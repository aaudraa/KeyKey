import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/authenticator/application/otp_clock.dart';

/// [builder]'ı o anki saatle çizer ve [active] iken saniyede birkaç kez
/// yeniler. Geri sayım ve TOTP kodları bununla güncel kalır.
///
/// Her karede saate bakan bir `Ticker` kullanır. Ekran görünmezken, örneğin
/// sekme arka plandayken, `TickerMode` onu durdurur. [active] `false` ise
/// hiç çalışmaz; HOTP gibi zamana bağlı olmayan kodlar için pil harcanmaz.
class OtpClockBuilder extends ConsumerStatefulWidget {
  const new({required this.active, required this.builder, super.key});

  final bool active;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  ConsumerState<OtpClockBuilder> createState() => _OtpClockBuilderState();
}

class _OtpClockBuilderState extends ConsumerState<OtpClockBuilder>
    with SingleTickerProviderStateMixin {
  /// Ekranın yenilendiği aralık. Geri sayım halkası bu adımla ilerler.
  static const _refreshStep = 250;

  late final Ticker _ticker = createTicker(_onTick);
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(OtpClockBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  DateTime _now() => ref.read(otpClockProvider)();

  void _sync() {
    if (widget.active && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration _) {
    final step = _now().millisecondsSinceEpoch ~/ _refreshStep;
    if (step != _step) setState(() => _step = step);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now());
}
