import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// 2FA çöp kutusu. Hesaplar 30 gün sonra kendiliğinden kalıcı olarak silinir.
///
/// Silinen 2FA anahtarı servise girişi engelleyebileceği için kalıcı silme
/// ayrıca uyarır.
class OtpTrashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(otpsControllerProvider);
    final controller = ref.read(otpsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trashTitle)),
      body: switch (state) {
        OtpsLoading() => const Center(child: CircularProgressIndicator()),
        OtpsLoaded(:final trashed) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.trashInfo(OtpRepository.trashRetention.inDays)),
            ),
            Expanded(
              child: trashed.isEmpty
                  ? Center(child: Text(l10n.trashEmpty))
                  : ListView(
                      children: [
                        for (final item in trashed)
                          ListTile(
                            title: Text(otpTitle(item.content, l10n)),
                            subtitle: switch (otpSubtitle(item.content)) {
                              final subtitle? => Text(subtitle),
                              null => null,
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: l10n.trashRestore,
                                  icon: const Icon(Icons.restore),
                                  onPressed: () => controller.restore(item),
                                ),
                                IconButton(
                                  tooltip: l10n.trashDelete,
                                  icon: const Icon(Icons.delete_forever),
                                  onPressed: () =>
                                      _confirmDelete(context, controller, item),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OtpsController controller,
    OtpItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trashDeleteTitle),
        content: Text(l10n.otpTrashDeleteMessage(otpTitle(item.content, l10n))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.biometricCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.trashDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.deletePermanently(item);
  }
}
