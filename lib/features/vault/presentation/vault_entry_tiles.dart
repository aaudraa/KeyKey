import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/last_saved.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_copy_icon.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/app/ui/record_avatar.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kasa listesinde parola satırı.
class LoginTile extends ConsumerWidget {
  const new({required this.item, super.key});

  final LoginItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final glass = KkGlass.of(context);
    final content = item.content;
    final name = content.name.trim();
    final idHex = loginIdHex(item.id);
    final title = Text(name.isEmpty ? '—' : name);
    return KkCard(
      flash: watchLastSaved(ref, savedLoginKey(idHex)),
      title: content.favorite
          ? Row(
              children: [
                Flexible(child: title),
                const SizedBox(width: 4),
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: glass.accent,
                  semanticLabel: l10n.favoriteMark,
                ),
              ],
            )
          : title,
      subtitle: content.username.isEmpty ? null : Text(content.username),
      leading: Hero(
        tag: loginAvatarHeroTag(idHex),
        child: RecordAvatar(login: content, name: content.name),
      ),
      trailing: content.password.isEmpty
          ? null
          : KkCopyIcon(
              tooltip: l10n.vaultCopyPassword,
              color: glass.accent,
              onCopy: () => copySensitive(context, ref, content.password),
            ),
      onTap: () => context.push(AppRoutes.vaultItem(idHex)),
    );
  }
}

/// Favori kayıtta adın yanında küçük yıldız.
Widget _titleWithStar(
  BuildContext context,
  String name, {
  required bool favorite,
}) {
  final title = Text(name);
  if (!favorite) return title;
  return Row(
    children: [
      Flexible(child: title),
      const SizedBox(width: 4),
      Icon(
        Icons.star_rounded,
        size: 14,
        color: KkGlass.of(context).accent,
        semanticLabel: AppLocalizations.of(context).favoriteMark,
      ),
    ],
  );
}

/// Kartın liste ve çöp satırındaki özeti: "Visa •••• 4242 · 12/28".
String cardSummary(AppLocalizations l10n, CardContent content, DateTime now) {
  final number = content.number;
  final expiry = content.expiry;
  return [
    if (number.isNotEmpty)
      [?content.cardBrand?.label, '•••• ${lastFour(number)}'].join(' '),
    if (expiry != null && expiry.isExpiredAt(now))
      l10n.cardExpired
    else if (expiry != null)
      expiry.format(),
  ].join(' · ');
}

/// Kartın listede görünen adı; ad boşsa marka ve son dört hane.
String cardTitle(CardContent content) {
  final name = content.displayName;
  return name.isEmpty ? '—' : name;
}

/// Kasa listesinde kart satırı. Tam numara görünmez, düğme kopyalar.
class CardTile extends ConsumerWidget {
  const new({required this.item, super.key});

  final CardItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final glass = KkGlass.of(context);
    final content = item.content;
    final idHex = loginIdHex(item.id);
    final summary = cardSummary(l10n, content, DateTime.now());
    return KkCard(
      flash: watchLastSaved(ref, savedCardKey(idHex)),
      title: _titleWithStar(
        context,
        cardTitle(content),
        favorite: content.favorite,
      ),
      subtitle: summary.isEmpty ? null : Text(summary),
      leading: RecordAvatar(
        login: null,
        name: content.name,
        icon: Icons.credit_card_rounded,
      ),
      trailing: content.number.isEmpty
          ? null
          : KkCopyIcon(
              tooltip: l10n.cardCopyNumber,
              color: glass.accent,
              onCopy: () => copySensitive(context, ref, content.number),
            ),
      onTap: () => context.push(AppRoutes.cardItem(idHex)),
    );
  }
}

/// Kasa listesinde not satırı. Metin listede gösterilmez: not çoğu zaman
/// sırrın kendisidir.
class NoteTile extends ConsumerWidget {
  const new({required this.item, super.key});

  final NoteItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = item.content;
    final idHex = loginIdHex(item.id);
    final name = content.name.trim();
    return KkCard(
      flash: watchLastSaved(ref, savedNoteKey(idHex)),
      title: _titleWithStar(
        context,
        name.isEmpty ? '—' : name,
        favorite: content.favorite,
      ),
      leading: RecordAvatar(
        login: null,
        name: content.name,
        icon: Icons.sticky_note_2_outlined,
      ),
      onTap: () => context.push(AppRoutes.noteItem(idHex)),
    );
  }
}
