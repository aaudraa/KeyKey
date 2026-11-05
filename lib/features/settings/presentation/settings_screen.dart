import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: Text(l10n.changePasswordTitle),
            onTap: () => context.push(AppRoutes.changePassword),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.settingsLockNow),
            onTap: () => ref.read(vaultControllerProvider.notifier).lock(),
          ),
        ],
      ),
    );
  }
}
