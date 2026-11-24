import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/presentation/card_face.dart';
import 'package:keykey/features/vault/presentation/detail_fields.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

enum _DetailAction { favorite, trash }

/// Bir kart kaydının ayrıntısı. Numara, güvenlik kodu ve PIN gizli gelir.
class CardDetailScreen extends ConsumerWidget {
  const new({required this.idHex, super.key});

  final String idHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(cardsControllerProvider);
    final item = findRecord(state, idHex);
    if (item == null) {
      return KkScaffold(
        appBar: kkAppBar(context),
        body: Center(
          child: state is RecordsLoaded<CardContent>
              ? Text(l10n.loginNotFound)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final content = item.content;
    final controller = ref.read(cardsControllerProvider.notifier);
    final name = content.name.trim();

    final secrets = <Widget>[
      if (content.number.isNotEmpty)
        DetailField(
          label: l10n.cardNumber,
          value: content.number,
          display: groupCardNumber(content.number),
          hidden: true,
        ),
      if (content.expiry case final expiry?)
        DetailField(label: l10n.cardExpiryShort, value: expiry.format()),
      if (content.securityCode.isNotEmpty)
        DetailField(
          label: l10n.cardSecurityCode,
          value: content.securityCode,
          hidden: true,
        ),
      if (content.pin.isNotEmpty)
        DetailField(label: l10n.cardPin, value: content.pin, hidden: true),
      if (content.cardholder.isNotEmpty)
        DetailField(label: l10n.cardholder, value: content.cardholder),
    ];
    final extra = <Widget>[
      if (content.folder != null)
        DetailField(label: l10n.loginFolder, value: content.folder!),
      if (content.notes.isNotEmpty)
        DetailField(label: l10n.loginNotes, value: content.notes),
    ];

    return KkScaffold(
      appBar: kkAppBar(
        context,
        actions: [
          KkCircleButton(
            icon: Icons.edit_rounded,
            tooltip: l10n.loginEdit,
            onPressed: () => context.push(AppRoutes.cardItemEdit(idHex)),
          ),
          KkMenuButton<_DetailAction>(
            tooltip: l10n.screenMore,
            onSelected: (action) => switch (action) {
              _DetailAction.favorite => unawaited(
                runRecordAction(
                  context,
                  () =>
                      controller.setFavorite(item, favorite: !content.favorite),
                ),
              ),
              _DetailAction.trash => unawaited(
                moveRecordToTrash(context, controller, item, l10n),
              ),
            },
            items: [
              KkMenuItem(
                value: _DetailAction.favorite,
                label: content.favorite
                    ? l10n.loginUnfavorite
                    : l10n.loginFavorite,
                icon: content.favorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
              ),
              KkMenuItem(
                value: _DetailAction.trash,
                label: l10n.loginMoveToTrash,
                icon: Icons.delete_outline_rounded,
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, navClearance(context)),
        children: [
          Text(
            name.isEmpty ? '—' : name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          CardFace(content: content, now: DateTime.now()),
          const SizedBox(height: 20),
          for (final rows in [secrets, extra])
            if (rows.isNotEmpty) ...[
              DetailFieldGroup(rows: rows),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 6),
          Text(
            l10n.loginLastChanged(
              MaterialLocalizations.of(context)
                  .formatMediumDate(item.updatedAt.toLocal()),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
