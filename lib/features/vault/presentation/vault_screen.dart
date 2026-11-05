import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Parola listesi: arama, favoriler, klasörler ve sıralama.
class VaultScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _search = TextEditingController();
  LoginFilter _filter = const LoginFilter();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navVault),
        actions: [
          PopupMenuButton<LoginSort>(
            tooltip: l10n.vaultSort,
            icon: const Icon(Icons.sort),
            initialValue: _filter.sort,
            onSelected: (sort) =>
                setState(() => _filter = _filter.copyWith(sort: sort)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: LoginSort.name,
                child: Text(l10n.vaultSortName),
              ),
              PopupMenuItem(
                value: LoginSort.recentlyUpdated,
                child: Text(l10n.vaultSortRecent),
              ),
            ],
          ),
          IconButton(
            tooltip: l10n.trashTitle,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.push(AppRoutes.vaultTrash),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state is LoginsLoaded
            ? () => context.push(AppRoutes.vaultNew)
            : null,
        icon: const Icon(Icons.add),
        label: Text(l10n.vaultAdd),
      ),
      body: switch (state) {
        LoginsLoading() => const Center(child: CircularProgressIndicator()),
        LoginsLoaded() => _loaded(context, l10n, state),
      },
    );
  }

  Widget _loaded(
    BuildContext context,
    AppLocalizations l10n,
    LoginsLoaded state,
  ) {
    final folders = foldersOf(state.items);
    final visible = filterLogins(state.indexed, _filter);
    final hasLogins = state.items.any((item) => !item.content.isTrashed);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SecretField(
            controller: _search,
            label: l10n.vaultSearch,
            obscure: false,
            textInputAction: TextInputAction.search,
            onChanged: (query) =>
                setState(() => _filter = _filter.copyWith(query: query)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: Text(l10n.vaultFavorites),
                avatar: const Icon(Icons.star_outline),
                selected: _filter.favoritesOnly,
                onSelected: (selected) => setState(
                  () => _filter = _filter.copyWith(favoritesOnly: selected),
                ),
              ),
              for (final folder in folders) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(folder),
                  avatar: const Icon(Icons.folder_outlined),
                  selected: _filter.folder == folder,
                  onSelected: (selected) => setState(
                    () => _filter = selected
                        ? _filter.copyWith(folder: folder)
                        : _filter.copyWith(clearFolder: true),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (state.unreadableCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(l10n.vaultUnreadable(state.unreadableCount)),
              ),
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      hasLogins ? l10n.vaultNoResults : l10n.vaultEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: visible.length,
                  itemBuilder: (context, index) =>
                      _LoginTile(item: visible[index]),
                ),
        ),
      ],
    );
  }
}

class _LoginTile extends StatelessWidget {
  const new({required this.item});

  final LoginItem item;

  @override
  Widget build(BuildContext context) {
    final content = item.content;
    final name = content.name.trim();
    return ListTile(
      leading: CircleAvatar(
        child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
      ),
      title: Text(name.isEmpty ? '—' : name, overflow: TextOverflow.ellipsis),
      subtitle: content.username.isEmpty
          ? null
          : Text(content.username, overflow: TextOverflow.ellipsis),
      trailing: content.favorite ? const Icon(Icons.star) : null,
      onTap: () => context.push(AppRoutes.vaultItem(loginIdHex(item.id))),
    );
  }
}
