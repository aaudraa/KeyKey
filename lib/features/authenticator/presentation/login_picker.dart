import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kullanıcının seçimi.
sealed class LoginPick {
  const new();
}

final class LoginPicked extends LoginPick {
  const new(this.id);

  final Uint8List id;
}

/// "Eşleştirmeyi kaldır" seçildi.
final class LoginUnlinked extends LoginPick {
  const new();
}

/// Bir parola kaydı seçtirir. Pencere kapatılırsa `null` döner.
Future<LoginPick?> pickLogin(BuildContext context, {required bool linked}) {
  return showKkSheet<LoginPick>(
    context,
    builder: (context) => _LoginPickerDialog(linked: linked),
  );
}

class _LoginPickerDialog extends ConsumerStatefulWidget {
  const new({required this.linked});

  /// Şu an bir eşleşme varsa kaldırma düğmesi gösterilir.
  final bool linked;

  @override
  ConsumerState<_LoginPickerDialog> createState() => _LoginPickerDialogState();
}

class _LoginPickerDialogState extends ConsumerState<_LoginPickerDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    final visible = state is LoginsLoaded
        ? filterLogins(state.indexed, LoginFilter(query: _search.text))
        : null;

    return KkSheetContent(
      title: l10n.otpLinkChoose,
      actions: [
        if (widget.linked)
          TextButton(
            onPressed: () => Navigator.pop(context, const LoginUnlinked()),
            child: Text(l10n.otpLinkRemove),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.biometricCancel),
        ),
      ],
      child: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SecretField(
                controller: _search,
                label: l10n.vaultSearch,
                obscure: false,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: switch (visible) {
                null => const Center(child: CircularProgressIndicator()),
                [] => Center(child: Text(l10n.vaultNoResults)),
                _ => ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    final name = item.content.name.trim();
                    return ListTile(
                      title: Text(
                        name.isEmpty ? '—' : name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.content.username.isEmpty
                          ? null
                          : Text(
                              item.content.username,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => Navigator.pop(context, LoginPicked(item.id)),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
