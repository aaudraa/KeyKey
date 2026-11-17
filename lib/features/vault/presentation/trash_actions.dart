import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

enum _TrashAction { restoreAll, emptyAll }

/// Çöp kutusunun üst çubuğundaki toplu işlemler: tümünü geri yükle ve
/// onaylı boşaltma. Çöp boşken düğme yoktur.
class TrashActions extends StatelessWidget {
  const new({
    required this.count,
    required this.emptyMessage,
    required this.onRestoreAll,
    required this.onEmptyAll,
    super.key,
  });

  final int count;

  /// Boşaltma onayındaki açıklama; 2FA çöpü ek uyarı taşır.
  final String emptyMessage;
  final Future<void> Function() onRestoreAll;
  final Future<void> Function() onEmptyAll;

  Future<void> _onSelected(BuildContext context, _TrashAction action) async {
    switch (action) {
      case _TrashAction.restoreAll:
        await onRestoreAll();
      case _TrashAction.emptyAll:
        final l10n = AppLocalizations.of(context);
        final confirmed = await showKkConfirm(
          context,
          title: l10n.trashEmptyTitle,
          message: emptyMessage,
          confirmLabel: l10n.trashEmptyConfirm,
          cancelLabel: l10n.biometricCancel,
          destructive: true,
        );
        if (confirmed) await onEmptyAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return KkMenuButton<_TrashAction>(
      tooltip: l10n.screenMore,
      onSelected: (action) => _onSelected(context, action),
      items: [
        KkMenuItem(
          value: _TrashAction.restoreAll,
          label: l10n.trashRestoreAll,
          icon: Icons.restore_rounded,
        ),
        KkMenuItem(
          value: _TrashAction.emptyAll,
          label: l10n.trashEmptyAll,
          icon: Icons.delete_forever_rounded,
        ),
      ],
    );
  }
}
