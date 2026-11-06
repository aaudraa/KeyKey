import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/presentation/autofill_app.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kasa açıldıktan sonra doldurulacak kaydın seçildiği ekran.
class AutofillPickScreen extends ConsumerStatefulWidget {
  const new({required this.target, super.key});

  final AutofillTarget target;

  @override
  ConsumerState<AutofillPickScreen> createState() => _AutofillPickScreenState();
}

class _AutofillPickScreenState extends ConsumerState<AutofillPickScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Değerleri alır, kasayı kilitler ve forma verir. Kilit önce gelir:
  /// anahtarlar silindikten sonra yalnızca seçilen iki değer kalır.
  Future<void> _fill(LoginItem item) async {
    final username = item.content.username;
    final password = item.content.password;
    ref.read(autofillDoneProvider.notifier).markDone();
    ref.read(vaultControllerProvider.notifier).lock();
    await ref
        .read(autofillBridgeProvider)
        .fill(username: username, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.autofillTitle),
        leading: IconButton(
          tooltip: l10n.autofillClose,
          icon: const Icon(Icons.close),
          onPressed: () => unawaited(ref.read(autofillBridgeProvider).cancel()),
        ),
      ),
      body: switch (state) {
        LoginsLoading() => const Center(child: CircularProgressIndicator()),
        LoginsLoaded() => _list(context, l10n, state),
      },
    );
  }

  Widget _list(
    BuildContext context,
    AppLocalizations l10n,
    LoginsLoaded state,
  ) {
    final items = filterLogins(state.indexed, LoginFilter(query: _query.text));
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.autofillFor(autofillTargetName(widget.target)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SecretField(
            controller: _query,
            label: l10n.vaultSearch,
            obscure: false,
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.items.isEmpty ? l10n.autofillEmpty : l10n.vaultNoResults,
              textAlign: TextAlign.center,
            ),
          ),
        for (final item in items)
          ListTile(
            leading: const Icon(Icons.key),
            title: Text(item.content.name.isEmpty ? '—' : item.content.name),
            subtitle: item.content.username.isEmpty
                ? null
                : Text(item.content.username),
            onTap: () => unawaited(_fill(item)),
          ),
      ],
    );
  }
}
