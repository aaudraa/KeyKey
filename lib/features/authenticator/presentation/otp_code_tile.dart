import 'package:flutter/material.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Listede bir hesabın menüsündeki işler.
enum OtpTileAction { edit, favorite, trash }

/// Bir hesabın kodu. TOTP'de geri sayım, HOTP'de kod üretme düğmesi vardır.
///
/// Dokununca kod kopyalanır. Süre bitmek üzereyken sıradaki kod da görünür.
class OtpCodeTile extends StatelessWidget {
  const new({
    required this.item,
    required this.now,
    required this.onCopy,
    required this.onAction,
    this.hotpCode,
    this.onGenerate,
    super.key,
  });

  /// Kalan süre bundan azsa sıradaki kod gösterilir.
  static const nextCodeThreshold = Duration(seconds: 10);

  /// Kalan süre bundan azsa geri sayım uyarı rengine döner.
  static const warningThreshold = Duration(seconds: 5);

  final OtpItem item;
  final DateTime now;

  /// HOTP'de son üretilen kod. Henüz üretilmediyse `null`.
  final String? hotpCode;
  final ValueChanged<String> onCopy;
  final VoidCallback? onGenerate;
  final ValueChanged<OtpTileAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final content = item.content;
    final parameters = content.parameters;
    final subtitle = otpSubtitle(content);

    final String? code;
    String? nextCode;
    Duration? remaining;
    switch (parameters.kind) {
      case OtpKind.totp:
        code = OtpGenerator.codeFor(parameters, now);
        remaining = OtpGenerator.remaining(now, parameters.period!);
        if (remaining <= nextCodeThreshold) {
          nextCode = OtpGenerator.nextTotp(parameters, now);
        }
      case OtpKind.hotp:
        code = hotpCode;
    }

    return InkWell(
      onTap: code == null ? null : () => onCopy(code!),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          otpTitle(content, l10n),
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (content.favorite) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star,
                          size: 16,
                          color: theme.colorScheme.primary,
                          semanticLabel: l10n.favoriteMark,
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Semantics(
                    label: code == null ? l10n.otpNoCode : spokenOtpCode(code),
                    hint: code == null ? null : l10n.otpCopyCode,
                    excludeSemantics: true,
                    child: Text(
                      code == null
                          ? formatOtpCode('•' * parameters.digits)
                          : formatOtpCode(code),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: code == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  if (nextCode != null)
                    Semantics(
                      label: l10n.otpNext(spokenOtpCode(nextCode)),
                      excludeSemantics: true,
                      child: Text(
                        l10n.otpNext(formatOtpCode(nextCode)),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (remaining != null)
              _Countdown(remaining: remaining, period: parameters.period!)
            else
              IconButton(
                tooltip: l10n.otpGenerate,
                icon: const Icon(Icons.refresh),
                onPressed: onGenerate,
              ),
            PopupMenuButton<OtpTileAction>(
              onSelected: onAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: OtpTileAction.edit,
                  child: Text(l10n.loginEdit),
                ),
                PopupMenuItem(
                  value: OtpTileAction.favorite,
                  child: Text(
                    content.favorite
                        ? l10n.loginUnfavorite
                        : l10n.loginFavorite,
                  ),
                ),
                PopupMenuItem(
                  value: OtpTileAction.trash,
                  child: Text(l10n.loginMoveToTrash),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const new({required this.remaining, required this.period});

  final Duration remaining;
  final int period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final warning = remaining <= OtpCodeTile.warningThreshold;
    final color = warning ? theme.colorScheme.error : theme.colorScheme.primary;
    // İlerleme çubuğu rolü verilmez: TalkBack değeri değişen ilerleme
    // çubuğunu her saniye okur. Kalan süre etikette durur, odaklanınca okunur.
    return Semantics(
      label: l10n.otpSecondsLeft(seconds),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: remaining.inMilliseconds / (period * 1000),
              color: color,
              strokeWidth: 3,
            ),
            Text(
              '$seconds',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
