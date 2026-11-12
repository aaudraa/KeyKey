import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/record_avatar.dart';
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

    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.trashTitle),
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
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: trashed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = trashed[index];
                        return KkCard(
                          leading: RecordAvatar(
                            login: null,
                            name: otpTitle(item.content, l10n),
                          ),
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
                                icon: Icon(
                                  Icons.restore_rounded,
                                  color: KkGlass.of(context).accent,
                                ),
                                onPressed: () => controller.restore(item),
                              ),
                              IconButton(
                                tooltip: l10n.trashDelete,
                                icon: Icon(
                                  Icons.delete_forever_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, controller, item),
                              ),
                            ],
                          ),
                        );
                      },
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
    final confirmed = await showKkSheet<bool>(
      context,
      builder: (context) => KkSheetContent(
        title: l10n.trashDeleteTitle,
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
        child: Text(l10n.otpTrashDeleteMessage(otpTitle(item.content, l10n))),
      ),
    );
    if (confirmed ?? false) await controller.deletePermanently(item);
  }
}
