import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Formdaki bir alanı saran cam kart. [onRemove] verilirse sonda küçük
/// kaldırma düğmesi durur (ek alanlar için).
class KkFieldCard extends StatelessWidget {
  const new({
    required this.child,
    this.onRemove,
    this.removeTooltip,
    super.key,
  });

  final Widget child;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassSurface(
        padding: EdgeInsetsDirectional.only(
          start: 4,
          end: onRemove == null ? 4 : 0,
          top: 2,
          bottom: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: child),
            if (onRemove != null)
              IconButton(
                tooltip:
                    removeTooltip ??
                    AppLocalizations.of(context).formRemoveField,
                icon: Icon(
                  Icons.close_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

/// "Daha fazla seçenek" altındaki bir ek alan.
class KkOption {
  const new({required this.label, required this.onAdd});

  final String label;
  final VoidCallback onAdd;
}

/// Formda ek alanların istenince eklendiği satır: dokununca açılır, her
/// seçenek başında "+" olan cam bir yonga olarak görünür. Seçenek yoksa
/// hiçbir şey çizmez.
class KkMoreOptions extends StatefulWidget {
  const new({required this.options, super.key});

  final List<KkOption> options;

  @override
  State<KkMoreOptions> createState() => _KkMoreOptionsState();
}

class _KkMoreOptionsState extends State<KkMoreOptions> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    final duration = KkMotion.of(context, KkMotion.base);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _open,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: glass.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.formMoreOptions,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: duration,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (i, option) in widget.options.indexed)
                        _StaggeredChip(
                          key: ValueKey(option.label),
                          index: i,
                          child: ActionChip(
                            avatar: Icon(
                              Icons.add_rounded,
                              color: glass.accent,
                            ),
                            label: Text(option.label),
                            onPressed: option.onAdd,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Yonganın girişi (madde 2.6): sırası gelince küçükten yaylanarak büyür
/// ve belirir. Kalan yongalar bir yonga kaldırılınca yeniden oynamaz.
class _StaggeredChip extends StatefulWidget {
  const new({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  State<_StaggeredChip> createState() => _StaggeredChipState();
}

class _StaggeredChipState extends State<_StaggeredChip>
    with SingleTickerProviderStateMixin {
  static const double _startScale = 0.8;

  late final AnimationController _motion = AnimationController(vsync: this);
  late Interval _window;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final delay =
        KkMotion.stagger * math.min(widget.index, KkMotion.staggerMax);
    final total = delay + KkMotion.base;
    _window = Interval(delay.inMicroseconds / total.inMicroseconds, 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      _motion
        ..duration = total
        ..forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, child) {
      final t = _window.transform(_motion.value);
      final scale =
          _startScale + (1 - _startScale) * KkMotion.spring.transform(t);
      return Opacity(
        opacity: KkMotion.standard.transform(t),
        child: Transform.scale(scale: scale, child: child),
      );
    },
    child: widget.child,
  );
}
