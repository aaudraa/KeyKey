import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/features/authenticator/application/otp_visibility.dart';
import 'package:keykey/features/authenticator/presentation/confirm_identity.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ek onay açıkken kodların yerine gösterilir.
class OtpGate extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(26)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.visibility_off_rounded,
                size: 48,
                color: KkGlass.of(context).accent,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.otpHiddenTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.otpHiddenBody, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => revealOtpCodes(context, ref),
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(l10n.otpReveal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kimliği doğrular ve doğrulanırsa kodları bu oturum için açar.
Future<void> revealOtpCodes(BuildContext context, WidgetRef ref) async {
  final confirmed = await confirmIdentity(context, ref);
  // Onay sürerken ekran kapandıysa veya kasa kilitlendiyse kodlar açılmaz;
  // yoksa bir sonraki açılışta onaysız görünürlerdi.
  if (!confirmed || !context.mounted) return;
  if (ref.read(vaultControllerProvider) is! VaultOpen) return;
  ref.read(otpRevealProvider.notifier).reveal();
}
