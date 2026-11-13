import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/last_saved.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_animated_items.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_copy_icon.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/app/ui/record_avatar.dart';
import 'package:keykey/features/backup/presentation/backup_reminder_banner.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kayıt simge kutusunun Hero etiketi: listeden ayrıntıya geçerken kutu
/// yerinden yeni yerine taşınır.
String loginAvatarHeroTag(String idHex) => 'login-avatar-$idHex';

enum _VaultAction { sortName, sortRecent, report, trash }

/// Parola listesi: arama, favoriler, klasörler ve sıralama.
class VaultScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  LoginFilter _filter = const LoginFilter();

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onAction(_VaultAction action) {
    switch (action) {
      case _VaultAction.sortName:
        setState(() => _filter = _filter.copyWith(sort: LoginSort.name));
      case _VaultAction.sortRecent:
        setState(
          () => _filter = _filter.copyWith(sort: LoginSort.recentlyUpdated),
        );
      case _VaultAction.report:
        unawaited(context.push(AppRoutes.vaultReport));
      case _VaultAction.trash:
        unawaited(context.push(AppRoutes.vaultTrash));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginsControllerProvider);
    return KkScaffold(
      appBar: kkRootAppBar(
        context,
        title: l10n.navVault,
        actions: [
          KkBarSearchButton(
            tooltip: l10n.vaultSearch,
            scrollController: _scroll,
            focusNode: _searchFocus,
          ),
          KkMenuButton<_VaultAction>(
            tooltip: l10n.screenMore,
            onSelected: _onAction,
            items: [
              KkMenuItem(
                value: _VaultAction.sortName,
                label: l10n.vaultSortName,
                icon: Icons.sort_by_alpha_rounded,
                checked: _filter.sort == LoginSort.name,
              ),
              KkMenuItem(
                value: _VaultAction.sortRecent,
                label: l10n.vaultSortRecent,
                icon: Icons.history_rounded,
                checked: _filter.sort == LoginSort.recentlyUpdated,
              ),
              KkMenuItem(
                value: _VaultAction.report,
                label: l10n.reportTitle,
                icon: Icons.health_and_safety_outlined,
                enabled: state is LoginsLoaded,
              ),
              KkMenuItem(
                value: _VaultAction.trash,
                label: l10n.trashTitle,
                icon: Icons.delete_outline_rounded,
              ),
            ],
          ),
        ],
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
    final active = state.items.where((item) => !item.content.isTrashed);
    final count = active.length;
    final hasFavorites = active.any((item) => item.content.favorite);
    final folders = foldersOf(state.items);
    // Süzgecin dayanağı kalmadıysa (son favori kalktı, klasör boşaldı)
    // bütün kayıtlar yeniden görünür.
    if (_filter.favoritesOnly && !hasFavorites) {
      _filter = _filter.copyWith(favoritesOnly: false);
    }
    if (_filter.folder != null && !folders.contains(_filter.folder)) {
      _filter = _filter.copyWith(clearFolder: true);
    }
    final visible = filterLogins(state.indexed, _filter);
    final glass = KkGlass.of(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SecretField(
            controller: _search,
            focusNode: _searchFocus,
            label: count > 0 ? l10n.vaultSearchCount(count) : l10n.vaultSearch,
            obscure: false,
            search: true,
            textInputAction: TextInputAction.search,
            onChanged: (query) =>
                setState(() => _filter = _filter.copyWith(query: query)),
          ),
        ),
        const BackupReminderBanner(),
        if (hasFavorites || folders.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                if (hasFavorites)
                  FilterChip(
                    label: Text(l10n.vaultFavorites),
                    avatar: Icon(Icons.star_rounded, color: glass.accent),
                    selected: _filter.favoritesOnly,
                    onSelected: (selected) => setState(
                      () => _filter = _filter.copyWith(favoritesOnly: selected),
                    ),
                  ),
                for (final folder in folders) ...[
                  if (hasFavorites || folder != folders.first)
                    const SizedBox(width: 8),
                  FilterChip(
                    label: Text(folder),
                    avatar: Icon(Icons.folder_outlined, color: glass.accent),
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: GlassSurface(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.vaultUnreadable(state.unreadableCount)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );

    return KkItemsView<LoginItem>(
      header: header,
      controller: _scroll,
      items: visible,
      keyOf: (item) => loginIdHex(item.id),
      // Altta yüzen menü için boşluk.
      padding: EdgeInsets.fromLTRB(16, 4, 16, navClearance(context)),
      empty: Text(
        count > 0 ? l10n.vaultNoResults : l10n.vaultEmpty,
        textAlign: TextAlign.center,
      ),
      itemBuilder: (context, item, index) => _LoginTile(item: item),
    );
  }
}

class _LoginTile extends ConsumerWidget {
  const new({required this.item});

  final LoginItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final glass = KkGlass.of(context);
    final content = item.content;
    final name = content.name.trim();
    final idHex = loginIdHex(item.id);
    final title = Text(name.isEmpty ? '—' : name);
    return KkCard(
      flash: watchLastSaved(ref, savedLoginKey(idHex)),
      title: content.favorite
          ? Row(
              children: [
                Flexible(child: title),
                const SizedBox(width: 4),
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: glass.accent,
                  semanticLabel: l10n.favoriteMark,
                ),
              ],
            )
          : title,
      subtitle: content.username.isEmpty ? null : Text(content.username),
      leading: Hero(
        tag: loginAvatarHeroTag(idHex),
        child: RecordAvatar(login: content, name: content.name),
      ),
      trailing: content.password.isEmpty
          ? null
          : KkCopyIcon(
              tooltip: l10n.vaultCopyPassword,
              color: glass.accent,
              onCopy: () => copySensitive(context, ref, content.password),
            ),
      onTap: () => context.push(AppRoutes.vaultItem(idHex)),
    );
  }
}
