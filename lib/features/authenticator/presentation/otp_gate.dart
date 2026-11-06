import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/authenticator/application/otp_visibility.dart';
import 'package:keykey/features/authenticator/presentation/confirm_identity.dart';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(l10n.otpHiddenTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.otpHiddenBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => revealOtpCodes(context, ref),
              icon: const Icon(Icons.fingerprint),
              label: Text(l10n.otpReveal),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kimliği doğrular ve doğrulanırsa kodları bu oturum için açar.
Future<void> revealOtpCodes(BuildContext context, WidgetRef ref) async {
  if (await confirmIdentity(context, ref)) {
    ref.read(otpRevealProvider.notifier).reveal();
  }
}
