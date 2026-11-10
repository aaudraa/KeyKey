import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/presentation/linked_otp_tile.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Bir parola kaydının ayrıntısı. Parolalar varsayılan olarak gizlidir.
class LoginDetailScreen extends ConsumerWidget {
  const new({required this.idHex, super.key});

  final String idHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    final item = findLogin(state, idHex);
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(content.name),
        actions: [
          IconButton(
            tooltip: content.favorite
                ? l10n.loginUnfavorite
                : l10n.loginFavorite,
            icon: Icon(content.favorite ? Icons.star : Icons.star_outline),
            onPressed: () =>
                controller.setFavorite(item, favorite: !content.favorite),
          ),
          IconButton(
            tooltip: l10n.loginEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppRoutes.vaultItemEdit(idHex)),
          ),
          IconButton(
            tooltip: l10n.loginMoveToTrash,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _moveToTrash(context, controller, item, l10n),
          ),
        ],
      ),
      body: _CardList(
        children: [
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
          for (final url in content.urls)
            _Field(label: l10n.loginUrl, value: url),
          for (final app in content.apps)
            ListTile(
              leading: const Icon(Icons.android),
              title: Text(
                l10n.loginApp,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              subtitle: Text(app.packageName),
            ),
          if (content.folder != null)
            _Field(label: l10n.loginFolder, value: content.folder!),
          for (final field in content.customFields)
            _Field(label: field.name, value: field.value, hidden: field.hidden),
          if (content.notes.isNotEmpty)
            _Field(label: l10n.loginNotes, value: content.notes),
          if (content.passwordHistory.isNotEmpty)
            ExpansionTile(
              leading: const Icon(Icons.history),
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
    await controller.moveToTrash(item, DateTime.now().toUtc());
    if (context.mounted) context.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.loginMovedToTrash),
        action: SnackBarAction(
          label: l10n.loginUndo,
          onPressed: () => unawaited(controller.restoreById(item.id)),
        ),
      ),
    );
  }
}

/// Her satır kendi kartında; aralarında küçük boşluk.
class _CardList extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, kNavClearance),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          Card(clipBehavior: Clip.antiAlias, child: children[index]),
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

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(sensitiveClipboardProvider).copy(widget.value);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final concealed = widget.hidden && !_revealed;
    return ListTile(
      title: Text(widget.label, style: Theme.of(context).textTheme.labelMedium),
      // Gizliyken ekran okuyucu noktaları değil "gizli" okur.
      subtitle: Semantics(
        label: concealed ? l10n.secretConcealed : null,
        excludeSemantics: concealed,
        child: Text(
          concealed ? '••••••••' : widget.value,
          style: widget.hidden
              ? const TextStyle(fontFamily: 'monospace')
              : null,
        ),
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
              ),
              onPressed: () => setState(() => _revealed = !_revealed),
            ),
          IconButton(
            tooltip: l10n.copy,
            icon: const Icon(Icons.copy_outlined),
            onPressed: _copy,
          ),
        ],
      ),
    );
  }
}
