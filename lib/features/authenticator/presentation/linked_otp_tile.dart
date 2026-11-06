import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/application/otp_visibility.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/otp_clock_builder.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/authenticator/presentation/otp_gate.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// [loginId] ile eşleştirilmiş, çöp kutusunda olmayan 2FA hesapları.
List<OtpItem> otpsLinkedTo(OtpsState state, Uint8List loginId) {
  if (state is! OtpsLoaded) return const [];
  return [
    for (final item in state.active)
      if (item.content.loginId case final id? when listEquals(id, loginId))
        item,
  ];
}

/// Parola kaydının ayrıntısında eşleşen 2FA hesabının kodu.
///
/// Dokununca kod kopyalanır. HOTP'de kod ancak istenince üretilir.
class LinkedOtpTile extends ConsumerStatefulWidget {
  const new({required this.item, super.key});

  final OtpItem item;

  @override
  ConsumerState<LinkedOtpTile> createState() => _LinkedOtpTileState();
}

class _LinkedOtpTileState extends ConsumerState<LinkedOtpTile> {
  String? _hotpCode;

  Future<void> _copy(String code) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(sensitiveClipboardProvider).copy(code);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.copiedWillClear(SensitiveClipboard.clearAfter.inSeconds),
          ),
        ),
      );
  }

  Future<void> _generate() async {
    try {
      final code = await ref
          .read(otpsControllerProvider.notifier)
          .nextHotpCode(widget.item);
      if (mounted) setState(() => _hotpCode = code);
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    } on OtpNotFoundException {
      // Hesap bu sırada silindi, ekran zaten güncellenecek.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final parameters = widget.item.content.parameters;
    final isTotp = parameters.kind == OtpKind.totp;

    final visible = ref.watch(otpCodesVisibleProvider);
    if (visible == null) return const SizedBox.shrink();
    if (!visible) {
      return ListTile(
        title: Text(l10n.loginOtpCode, style: theme.textTheme.labelMedium),
        subtitle: Text(l10n.otpHiddenTitle),
        trailing: TextButton(
          onPressed: () => revealOtpCodes(context, ref),
          child: Text(l10n.otpReveal),
        ),
      );
    }

    return OtpClockBuilder(
      active: isTotp,
      builder: (context, now) {
        final code = isTotp ? OtpGenerator.codeFor(parameters, now) : _hotpCode;
        final seconds = isTotp
            ? (OtpGenerator.remaining(now, parameters.period!).inMilliseconds /
                      1000)
                  .ceil()
            : null;
        return ListTile(
          title: Text(l10n.loginOtpCode, style: theme.textTheme.labelMedium),
          subtitle: Text(
            formatOtpCode(code ?? '•' * parameters.digits),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: code == null ? null : theme.colorScheme.primary,
            ),
          ),
          onTap: code == null ? null : () => _copy(code),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (seconds != null)
                Semantics(
                  label: l10n.otpSecondsLeft(seconds),
                  child: ExcludeSemantics(child: Text('$seconds')),
                )
              else
                IconButton(
                  tooltip: l10n.otpGenerate,
                  icon: const Icon(Icons.refresh),
                  onPressed: _generate,
                ),
              IconButton(
                tooltip: l10n.copy,
                icon: const Icon(Icons.copy_outlined),
                onPressed: code == null ? null : () => _copy(code),
              ),
            ],
          ),
        );
      },
    );
  }
}
