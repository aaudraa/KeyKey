import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/app/ui/sensitive_selectable_text.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/presentation/detail_fields.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

enum _DetailAction { favorite, trash }

/// Bir güvenli notun ayrıntısı. Metin seçilebilir; kopyalama hep hassas
/// pano kuralından geçer.
class NoteDetailScreen extends ConsumerWidget {
  const new({required this.idHex, super.key});

  final String idHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(notesControllerProvider);
    final item = findRecord(state, idHex);
    if (item == null) {
      return KkScaffold(
        appBar: kkAppBar(context),
        body: Center(
          child: state is RecordsLoaded<NoteContent>
              ? Text(l10n.loginNotFound)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final content = item.content;
    final controller = ref.read(notesControllerProvider.notifier);
    final name = content.name.trim();

    return KkScaffold(
      appBar: kkAppBar(
        context,
        actions: [
          KkCircleButton(
            icon: Icons.edit_rounded,
            tooltip: l10n.loginEdit,
            onPressed: () => context.push(AppRoutes.noteItemEdit(idHex)),
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
          Icon(
            Icons.sticky_note_2_outlined,
            size: 48,
            color: KkGlass.of(context).accent,
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? '—' : name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          if (content.text.isNotEmpty) ...[
            GlassSurface(
              padding: const EdgeInsets.all(16),
              child: SensitiveSelectableText(
                content.text,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: Text(l10n.noteCopy),
                onPressed: () =>
                    unawaited(copySensitive(context, ref, content.text)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (content.folder != null) ...[
            DetailFieldGroup(
              rows: [
                DetailField(label: l10n.loginFolder, value: content.folder!),
              ],
            ),
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
