import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/sync/application/sync_controller.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:keykey/features/sync/presentation/sync_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Son eşitlemede klasörde görülen telefonlar. Bu telefon başta; ötekiler
/// kaldırılabilir.
class SyncDevices extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final devices = [...ref.watch(syncControllerProvider).devices]
      ..sort((a, b) {
        if (a.self != b.self) return a.self ? -1 : 1;
        return a.device.compareTo(b.device);
      });
    if (devices.isEmpty) return const SizedBox.shrink();
    final now = ref.read(syncClockProvider)();
    return KkSection(
      title: l10n.syncDevices,
      children: [
        for (final device in devices)
          ListTile(
            leading: KkIconBox(
              icon: device.self
                  ? Icons.smartphone_rounded
                  : Icons.phone_android_rounded,
            ),
            title: Text(_label(l10n, device)),
            subtitle: device.modified == null
                ? null
                : KkRowSubtitle(syncAgo(l10n, device.modified!, now)),
            trailing: device.self
                ? null
                : TextButton(
                    onPressed: () => unawaited(_remove(context, ref, device)),
                    child: Text(l10n.syncRemove),
                  ),
          ),
      ],
    );
  }

  static String _label(AppLocalizations l10n, SyncDevice device) {
    final name = device.name;
    if (device.self) {
      return name == null || name.isEmpty
          ? l10n.syncThisPhone
          : '${l10n.syncThisPhone} · $name';
    }
    return '${name == null || name.isEmpty ? l10n.syncUnknownPhone : name}'
        ' · ${device.device}';
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    SyncDevice device,
  ) async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final name = device.name;
    final confirmed = await showKkConfirm(
      context,
      title: l10n.syncRemoveTitle(
        name == null || name.isEmpty ? device.device : name,
      ),
      message: l10n.syncRemoveBody,
      confirmLabel: l10n.syncRemove,
      cancelLabel: l10n.syncCancel,
      destructive: true,
    );
    if (!confirmed) return;
    final sync = ref.read(settingsControllerProvider)?.sync;
    if (sync == null) return;
    try {
      await ref.read(syncServiceProvider).removeDevice(sync, device.device);
    } on SyncTransportException catch (error) {
      snack(syncFailureText(l10n, error.kind));
      return;
    }
    snack(l10n.syncRemoved);
    // Listeyi yeniler.
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }
}
