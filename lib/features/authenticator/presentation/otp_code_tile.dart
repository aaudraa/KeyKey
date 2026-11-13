import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_rolling_text.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/record_avatar.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/authenticator/presentation/otp_ring.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Bir hesabın kartındaki işler (uzun basınca açılır).
enum OtpTileAction { edit, favorite, trash }

/// Bir hesabın kodu. TOTP'de süre halkası, HOTP'de kod üretme düğmesi
/// vardır.
///
/// Dokununca kod kopyalanır. Süre bitmek üzereyken sıradaki kod da görünür.
/// Düzenle, favori ve çöp kutusu karta uzun basınca açılan pencerededir;
/// ekran okuyucuda kartın işlem listesinde de bulunur.
class OtpCodeTile extends StatelessWidget {
  const new({
    required this.item,
    required this.now,
    required this.onCopy,
    required this.onAction,
    this.hotpCode,
    this.onGenerate,
    this.linkedLogin,
    this.flash = false,
    super.key,
  });

  /// Son kaydedilen hesap: kart bir kez parlar ([KkCard.flash]).
  final bool flash;

  /// Kalan süre bundan azsa sıradaki kod gösterilir.
  static const nextCodeThreshold = Duration(seconds: 10);

  /// Normal yazı boyutundaki kart yüksekliği.
  static const double height = 72;

  final OtpItem item;
  final DateTime now;

  /// HOTP'de son üretilen kod. Henüz üretilmediyse `null`.
  final String? hotpCode;
  final ValueChanged<String> onCopy;
  final VoidCallback? onGenerate;
  final ValueChanged<OtpTileAction> onAction;

  /// Bağlı parola kaydı; uygulaması varsa simgesi kartın solunda görünür.
  final LoginContent? linkedLogin;

  Future<void> _showActions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final favorite = item.content.favorite;
    final action = await showKkSheet<OtpTileAction>(
      context,
      builder: (context) {
        final accent = KkGlass.of(context).accent;
        ListTile row(OtpTileAction value, IconData icon, String label) =>
            ListTile(
              leading: Icon(icon, color: accent),
              title: Text(label),
              onTap: () => Navigator.pop(context, value),
            );
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      otpTitle(item.content, l10n),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                row(OtpTileAction.edit, Icons.edit_rounded, l10n.loginEdit),
                row(
                  OtpTileAction.favorite,
                  favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  favorite ? l10n.loginUnfavorite : l10n.loginFavorite,
                ),
                row(
                  OtpTileAction.trash,
                  Icons.delete_outline_rounded,
                  l10n.loginMoveToTrash,
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action != null) onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    final content = item.content;
    final parameters = content.parameters;
    final subtitle = otpSubtitle(content);
    final title = otpTitle(content, l10n);

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

    final small = theme.textTheme.labelMedium;
    final muted = small?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final heading = Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (subtitle != null) ...[
          // Süs; ekran okuyucu ad ile hesabı ayrı satırda okur.
          ExcludeSemantics(child: Text(' · ', style: muted)),
          Flexible(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
        ],
        if (content.favorite) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.star_rounded,
            size: 14,
            color: glass.accent,
            semanticLabel: l10n.favoriteMark,
          ),
        ],
      ],
    );

    final Widget codeLine;
    if (code == null) {
      // Sayaçlı hesapta kod istenince üretilir.
      codeLine = Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: onGenerate,
          child: Text(l10n.otpGenerate),
        ),
      );
    } else {
      codeLine = Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Semantics(
            label: spokenOtpCode(code),
            hint: l10n.otpCopyCode,
            excludeSemantics: true,
            // Kod yenilenince değişen rakamlar kayar (madde 3.4).
            child: KkRollingText(
              text: formatOtpCode(code),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (nextCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Semantics(
                label: l10n.otpNext(spokenOtpCode(nextCode)),
                excludeSemantics: true,
                child: Text(
                  l10n.otpNext(formatOtpCode(nextCode)),
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final trailing = remaining != null
        ? OtpRing(remaining: remaining, period: parameters.period!)
        : code == null
        ? null
        : IconButton(
            tooltip: l10n.otpGenerate,
            icon: Icon(Icons.refresh_rounded, color: glass.accent),
            onPressed: onGenerate,
          );

    return KkCard(
      flash: flash,
      minHeight: height,
      title: heading,
      subtitle: codeLine,
      leading: RecordAvatar(login: linkedLogin, name: title),
      onTap: code == null ? null : () => onCopy(code!),
      onLongPress: () => _showActions(context),
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.loginEdit): () =>
            onAction(OtpTileAction.edit),
        CustomSemanticsAction(
          label: content.favorite ? l10n.loginUnfavorite : l10n.loginFavorite,
        ): () =>
            onAction(OtpTileAction.favorite),
        CustomSemanticsAction(label: l10n.loginMoveToTrash): () =>
            onAction(OtpTileAction.trash),
      },
      trailing: trailing == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: trailing,
            ),
    );
  }
}
