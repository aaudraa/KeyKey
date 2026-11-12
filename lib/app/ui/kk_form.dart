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
          top: 4,
          bottom: 4,
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
                      for (final option in widget.options)
                        ActionChip(
                          avatar: Icon(Icons.add_rounded, color: glass.accent),
                          label: Text(option.label),
                          onPressed: option.onAdd,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
