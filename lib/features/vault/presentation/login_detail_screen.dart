import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_copy_icon.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/app/ui/kk_secret_text.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/app/ui/record_avatar.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/presentation/linked_otp_tile.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

enum _DetailAction { favorite, trash }

/// Bir parola kaydının ayrıntısı. Parolalar varsayılan olarak gizlidir.
class LoginDetailScreen extends ConsumerWidget {
  const new({required this.idHex, super.key});

  final String idHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(loginsControllerProvider);
    final item = findLogin(state, idHex);
    if (item == null) {
      return KkScaffold(
        appBar: kkAppBar(context),
        body: Center(
          child: state is LoginsLoaded
              ? Text(l10n.loginNotFound)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final content = item.content;
    final controller = ref.read(loginsControllerProvider.notifier);
    final linkedOtps = otpsLinkedTo(ref.watch(otpsControllerProvider), item.id);
    final name = content.name.trim();

    final cards = <Widget>[
      if (content.username.isNotEmpty)
        _Field(label: l10n.loginUsername, value: content.username),
      if (content.password.isNotEmpty)
        _Field(
          label: l10n.loginPassword,
          value: content.password,
          hidden: true,
        ),
      for (final otp in linkedOtps)
        LinkedOtpTile(key: ValueKey(otpIdHex(otp)), item: otp),
      for (final url in content.urls) _Field(label: l10n.loginUrl, value: url),
      for (final app in content.apps)
        ListTile(
          leading: Icon(
            Icons.android_rounded,
            color: KkGlass.of(context).accent,
          ),
          title: Text(l10n.loginApp, style: theme.textTheme.labelMedium),
          subtitle: Text(app.packageName),
        ),
      if (content.folder != null)
        _Field(label: l10n.loginFolder, value: content.folder!),
      for (final field in content.customFields)
        _Field(label: field.name, value: field.value, hidden: field.hidden),
      if (content.notes.isNotEmpty)
        _Field(label: l10n.loginNotes, value: content.notes),
      if (content.passwordHistory.isNotEmpty)
        Theme(
          // Açılır kartın kendi çizgileri cam kartta görünmesin.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(l10n.loginHistory(content.passwordHistory.length)),
            children: [
              for (final entry in content.passwordHistory)
                _Field(
                  label: MaterialLocalizations.of(context)
                      .formatMediumDate(entry.changedAt.toLocal()),
                  value: entry.password,
                  hidden: true,
                ),
            ],
          ),
        ),
    ];

    return KkScaffold(
      appBar: kkAppBar(
        context,
        actions: [
          KkCircleButton(
            icon: Icons.edit_rounded,
            tooltip: l10n.loginEdit,
            onPressed: () => context.push(AppRoutes.vaultItemEdit(idHex)),
          ),
          KkMenuButton<_DetailAction>(
            tooltip: l10n.screenMore,
            onSelected: (action) => switch (action) {
              _DetailAction.favorite => unawaited(
                controller.setFavorite(item, favorite: !content.favorite),
              ),
              _DetailAction.trash => unawaited(
                _moveToTrash(context, controller, item, l10n),
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
          Center(
            child: Hero(
              tag: loginAvatarHeroTag(idHex),
              child: RecordAvatar(login: content, name: content.name, size: 72),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? '—' : name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (content.urls.isNotEmpty)
            Text(
              content.urls.first,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 20),
          for (final card in cards) ...[
            GlassSurface(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(22)),
                child: Material(type: MaterialType.transparency, child: card),
              ),
            ),
            const SizedBox(height: 10),
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

  Future<void> _moveToTrash(
    BuildContext context,
    LoginsController controller,
    LoginItem item,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    await controller.moveToTrash(item, DateTime.now().toUtc());
    if (context.mounted) context.pop();
    if (!rootContext.mounted) {
      messenger.hideCurrentSnackBar();
      return;
    }
    showKkSnack(
      rootContext,
      l10n.loginMovedToTrash,
      action: SnackBarAction(
        label: l10n.loginUndo,
        onPressed: () => unawaited(controller.restoreById(item.id)),
      ),
    );
  }
}

/// Etiketli bir değer. [hidden] ise göster düğmesine basılana kadar gizlidir.
///
/// Kilitlenince ekran kapandığı için açılan değer de yeniden gizlenir.
class _Field extends ConsumerStatefulWidget {
  const new({required this.label, required this.value, this.hidden = false});

  final String label;
  final String value;
  final bool hidden;

  @override
  ConsumerState<_Field> createState() => _FieldState();
}

class _FieldState extends ConsumerState<_Field> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = KkGlass.of(context).accent;
    final concealed = widget.hidden && !_revealed;
    return ListTile(
      title: Text(widget.label, style: Theme.of(context).textTheme.labelMedium),
      // Gizliyken ekran okuyucu noktaları değil "gizli" okur.
      subtitle: Semantics(
        label: concealed ? l10n.secretConcealed : null,
        excludeSemantics: concealed,
        child: widget.hidden
            ? KkSecretText(
                text: widget.value,
                revealed: _revealed,
                style: const TextStyle(fontFamily: 'monospace'),
              )
            : Text(widget.value),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.hidden)
            IconButton(
              tooltip: concealed ? l10n.secretShow : l10n.secretHide,
              icon: Icon(
                concealed
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: accent,
              ),
              onPressed: () => setState(() => _revealed = !_revealed),
            ),
          KkCopyIcon(
            tooltip: l10n.copy,
            color: accent,
            onCopy: () => copySensitive(context, ref, widget.value),
          ),
        ],
      ),
    );
  }
}
