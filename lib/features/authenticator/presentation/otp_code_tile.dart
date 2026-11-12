import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/record_avatar.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/vault/data/login_content.dart';
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
    this.linkedLogin,
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

  /// Bağlı parola kaydı; uygulaması varsa simgesi kartta silik görünür.
  final LoginContent? linkedLogin;

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

    final linked = linkedLogin;
    final codeStyle = theme.textTheme.titleLarge?.copyWith(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: code == null
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.primary,
      letterSpacing: 1,
    );
    final nextStyle = theme.textTheme.labelSmall?.copyWith(
      fontFamily: 'monospace',
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Yazı büyütülmüşse kod sağa sığmaz; adın altına iner.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final codeColumn = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Semantics(
          label: code == null ? l10n.otpNoCode : spokenOtpCode(code),
          hint: code == null ? null : l10n.otpCopyCode,
          excludeSemantics: true,
          child: Text(
            code == null
                ? formatOtpCode('•' * parameters.digits)
                : formatOtpCode(code),
            style: codeStyle,
            maxLines: 1,
          ),
        ),
        // Sıradaki kodun yeri hep ayrılı: kart boyu değişmesin.
        if (nextCode != null)
          Semantics(
            label: l10n.otpNext(spokenOtpCode(nextCode)),
            excludeSemantics: true,
            child: Text(
              l10n.otpNext(formatOtpCode(nextCode)),
              style: nextStyle,
              maxLines: 1,
            ),
          )
        else
          Text('', style: nextStyle),
      ],
    );

    return KkCard(
      title: Row(
        children: [
          Flexible(child: Text(otpTitle(content, l10n))),
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
      subtitle: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [?subtitle == null ? null : Text(subtitle), codeColumn],
            )
          : (subtitle == null ? null : Text(subtitle)),
      leading: RecordAvatar(login: linked, name: otpTitle(content, l10n)),
      onTap: code == null ? null : () => onCopy(code!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!stacked) ...[codeColumn, const SizedBox(width: 8)],
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
                  content.favorite ? l10n.loginUnfavorite : l10n.loginFavorite,
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
        dimension: 32,
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
