import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/vault/password_policy.dart';
import 'package:keykey/features/generator/data/wordlists.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Parolanın kaba güç tahmini. Yaygın parola listesi yüklenene kadar yalnızca
/// yerleşik kurallarla çalışır.
class PasswordStrengthMeter extends ConsumerWidget {
  const new({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final common = ref.watch(commonPasswordsProvider).value ?? const {};
    final strength = PasswordPolicy.strengthOf(password, common: common);
    final (value, color, label) = switch (strength) {
      // Renksiz: güç, çubuğun boyu ve yanındaki metinle anlaşılır.
      PasswordStrength.tooShort => (
        0.1,
        colors.onSurface,
        l10n.strengthTooShort,
      ),
      PasswordStrength.weak => (0.35, colors.onSurface, l10n.strengthWeak),
      PasswordStrength.fair => (0.65, colors.onSurface, l10n.strengthFair),
      PasswordStrength.strong => (1.0, colors.onSurface, l10n.strengthStrong),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          // Değer değiştikçe boy yumuşak kayar (madde 3.3).
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: KkMotion.of(context, KkMotion.base),
            curve: KkMotion.standard,
            builder: (context, width, _) =>
                LinearProgressIndicator(value: width, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${l10n.strengthTitle}: $label',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
