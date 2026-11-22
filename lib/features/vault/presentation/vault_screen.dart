import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/secret_field.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_animated_items.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/presentation/backup_reminder_banner.dart';
import 'package:keykey/features/backup/presentation/login_import_screen.dart';
import 'package:keykey/features/backup/presentation/restore_screen.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/vault_entries.dart';
import 'package:keykey/features/vault/presentation/bulk_actions.dart';
import 'package:keykey/features/vault/presentation/folder_suggestions.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/vault_entry_tiles.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kayıt simge kutusunun Hero etiketi: listeden ayrıntıya geçerken kutu
/// yerinden yeni yerine taşınır.
String loginAvatarHeroTag(String idHex) => 'login-avatar-$idHex';

enum _VaultAction { sortName, sortRecent, report, trash }

/// Bir kayıt türünün listesi: Parolalar, Kartlar ya da Notlar sekmesi.
/// Arama, favoriler, klasörler, sıralama ve çöp kutusu o türe ait.
class VaultScreen extends ConsumerStatefulWidget {
  const new({this.kind = VaultKind.login, super.key});

  final VaultKind kind;

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  late LoginFilter _filter = LoginFilter(kind: widget.kind);

  /// Bu açılışta seçilen sıralama; ayara yazılana kadar ekranda bu görünür.
  LoginSort? _sort;

  /// Toplu seçimdeki kayıtların kimlikleri; boşsa seçim kapalı.
  final Set<String> _selected = {};

  /// Son çizimde görünen, süzülmüş kayıtlar. Seçim çubuğu bunlarla çalışır.
  List<VaultEntry> _visible = const [];

  bool get _selecting => _selected.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Başka sekmeye geçilince bu sekme görünmez ve zamanlayıcıları durur;
    // seçim bırakılır.
    if (!TickerMode.valuesOf(context).enabled) _selected.clear();
  }

  void _toggle(String idHex) => setState(() {
    if (!_selected.remove(idHex)) _selected.add(idHex);
  });

  void _clearSelection() => setState(_selected.clear);

  List<VaultEntry> get _selectedEntries => [
    for (final entry in _visible)
      if (_selected.contains(loginIdHex(entry.id))) entry,
  ];

  Future<void> _trashSelected() async {
    final l10n = AppLocalizations.of(context);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final entries = _selectedEntries;
    final bulk = BulkVault(ref);
    setState(_selected.clear);
    final int failed;
    try {
      failed = await bulk.moveToTrash(entries, DateTime.now().toUtc());
    } on VaultLockedException {
      return;
    }
    if (!rootContext.mounted) return;
    final moved = entries.length - failed;
    if (failed > 0) {
      showKkSnack(rootContext, l10n.bulkFailed(failed, entries.length));
      return;
    }
    showKkSnack(
      rootContext,
      l10n.bulkMovedToTrash(moved),
      action: KkSnackAction(
        label: l10n.loginUndo,
        onPressed: () =>
            unawaited(bulk.restore(entries).catchError((Object _) => 0)),
      ),
    );
  }

  Future<void> _moveSelected(List<String> folders) async {
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    final entries = _selectedEntries;
    final bulk = BulkVault(ref);
    // Yeni ad, seçilmeyen kayıtların (bütün türlerin) klasörleriyle eşlenir;
    // seçilenlerin kendi klasörü sayılmaz, yoksa "is" hiç "İs" yapılamazdı.
    final others = switch (ref.read(vaultEntriesProvider)) {
      VaultEntriesLoaded(:final entries) => foldersOfEntries(
        entries.where((entry) => !_selected.contains(loginIdHex(entry.id))),
      ),
      VaultEntriesLoading() => const <String>[],
    };
    final choice = await showKkSheet<_FolderChoice>(
      context,
      builder: (context) =>
          _FolderSheet(folders: folders, matchAgainst: others),
    );
    if (!mounted || choice == null) return;
    setState(_selected.clear);
    try {
      final failed = await bulk.moveToFolder(entries, choice.folder);
      if (failed > 0) snack(l10n.bulkFailed(failed, entries.length));
    } on VaultLockedException {
      // Kasa kilitlendi, yönlendirme kilit ekranına gidiyor.
    }
  }

  PreferredSizeWidget _selectionBar(
    BuildContext context,
    AppLocalizations l10n,
    List<String> folders,
  ) {
    final theme = Theme.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: l10n.selectionClose,
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearSelection,
      ),
      title: Semantics(
        liveRegion: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.selectedCount(_selected.length),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: l10n.selectAll,
          icon: const Icon(Icons.select_all_rounded),
          onPressed: () => setState(
            () =>
                _selected.addAll(_visible.map((entry) => loginIdHex(entry.id))),
          ),
        ),
        IconButton(
          tooltip: l10n.moveToFolder,
          icon: const Icon(Icons.drive_file_move_outline),
          onPressed: () => unawaited(_moveSelected(folders)),
        ),
        IconButton(
          tooltip: l10n.loginMoveToTrash,
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => unawaited(_trashSelected()),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

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
        _setSort(LoginSort.name);
      case _VaultAction.sortRecent:
        _setSort(LoginSort.recentlyUpdated);
      case _VaultAction.report:
        unawaited(context.push(AppRoutes.vaultReport));
      case _VaultAction.trash:
        unawaited(context.push(AppRoutes.trashOf(widget.kind)));
    }
  }

  /// Seçim kasadaki ayara yazılır; kilitten sonra da kalır.
  void _setSort(LoginSort sort) {
    setState(() => _sort = sort);
    unawaited(
      ref
          .read(settingsControllerProvider.notifier)
          .setVaultSort(sort)
          .catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = widget.kind;
    final state = ref.watch(vaultEntriesProvider);
    final loginsReady = ref.watch(loginsControllerProvider) is LoginsLoaded;
    final savedSort = ref.watch(
      settingsControllerProvider.select((settings) => settings?.vaultSort),
    );
    // Ayar yazılınca yerel seçim bırakılır; üç sekme aynı ayarı izler.
    if (_sort != null && _sort == savedSort) _sort = null;
    _filter = _filter.copyWith(sort: _sort ?? savedSort ?? LoginSort.name);
    final view = state is VaultEntriesLoaded ? _prepare(state) : null;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: KkScaffold(
        appBar: _selecting
            ? _selectionBar(context, l10n, view?.folders ?? const [])
            : kkRootAppBar(
                context,
                title: switch (kind) {
                  VaultKind.login => l10n.navPasswords,
                  VaultKind.card => l10n.navCards,
                  VaultKind.note => l10n.navNotes,
                },
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
                      if (kind == VaultKind.login)
                        KkMenuItem(
                          value: _VaultAction.report,
                          label: l10n.reportTitle,
                          icon: Icons.health_and_safety_outlined,
                          enabled: loginsReady,
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
          VaultEntriesLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          VaultEntriesLoaded() => _loaded(context, l10n, state, view!),
        },
      ),
    );
  }

  /// Süzgeci kayıtlara uydurur ve görünen listeyi hesaplar. Görünmeyen
  /// kayıtlar seçimden düşer (arama daraldı, kayıt silindi).
  _VaultView _prepare(VaultEntriesLoaded state) {
    final kind = widget.kind;
    final ofKind = state.entries.where((entry) => entry.kind == kind);
    final active = ofKind.where((entry) => !entry.isTrashed);
    final hasFavorites = active.any((entry) => entry.favorite);
    final folders = foldersOfEntries(ofKind);
    // Süzgecin dayanağı kalmadıysa (son favori kalktı, klasör boşaldı)
    // bütün kayıtlar yeniden görünür.
    if (_filter.favoritesOnly && !hasFavorites) {
      _filter = _filter.copyWith(favoritesOnly: false);
    }
    if (_filter.folder != null && !folders.contains(_filter.folder)) {
      _filter = _filter.copyWith(clearFolder: true);
    }
    final visible = filterEntries(state.indexed, _filter);
    _visible = visible;
    final visibleIds = {for (final entry in visible) loginIdHex(entry.id)};
    _selected.retainWhere(visibleIds.contains);
    return (
      count: active.length,
      hasFavorites: hasFavorites,
      folders: folders,
      visible: visible,
    );
  }

  Widget _loaded(
    BuildContext context,
    AppLocalizations l10n,
    VaultEntriesLoaded state,
    _VaultView view,
  ) {
    final kind = widget.kind;
    final (:count, :hasFavorites, :folders, :visible) = view;
    final glass = KkGlass.of(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SecretField(
            controller: _search,
            plain: PlainKeyboard.text,
            focusNode: _searchFocus,
            label: count == 0
                ? l10n.vaultSearch
                : switch (kind) {
                    VaultKind.login => l10n.vaultSearchCount(count),
                    VaultKind.card => l10n.cardsSearchCount(count),
                    VaultKind.note => l10n.notesSearchCount(count),
                  },
            obscure: false,
            search: true,
            textInputAction: TextInputAction.search,
            onChanged: (query) =>
                setState(() => _filter = _filter.copyWith(query: query)),
          ),
        ),
        // Yedek hatırlatıcısı ve okunamayan kayıt uyarısı bütün kasa için;
        // açılıştaki sekmede, Parolalar'da bir kez görünür.
        if (kind == VaultKind.login) const BackupReminderBanner(),
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
        if (kind == VaultKind.login && state.unreadableCount > 0)
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

    return KkItemsView<VaultEntry>(
      header: header,
      controller: _scroll,
      items: visible,
      keyOf: (entry) => switch (entry) {
        LoginEntry() => loginIdHex(entry.id),
        CardEntry() => 'card:${loginIdHex(entry.id)}',
        NoteEntry() => 'note:${loginIdHex(entry.id)}',
      },
      // Altta yüzen menü için boşluk.
      padding: EdgeInsets.fromLTRB(16, 4, 16, navClearance(context)),
      empty: count > 0
          ? Text(l10n.vaultNoResults, textAlign: TextAlign.center)
          : switch (kind) {
              VaultKind.login => const _EmptyVault(),
              VaultKind.card => Text(
                l10n.cardsEmpty,
                textAlign: TextAlign.center,
              ),
              VaultKind.note => Text(
                l10n.notesEmpty,
                textAlign: TextAlign.center,
              ),
            },
      itemBuilder: (context, entry, index) {
        final idHex = loginIdHex(entry.id);
        final selection = _selecting
            ? TileSelection(
                selected: _selected.contains(idHex),
                onToggle: () => _toggle(idHex),
              )
            : null;
        final onLongPress = _selecting ? null : () => _toggle(idHex);
        return switch (entry) {
          LoginEntry(:final item) => LoginTile(
            item: item,
            selection: selection,
            onLongPress: onLongPress,
          ),
          CardEntry(:final item) => CardTile(
            item: item,
            selection: selection,
            onLongPress: onLongPress,
          ),
          NoteEntry(:final item) => NoteTile(
            item: item,
            selection: selection,
            onLongPress: onLongPress,
          ),
        };
      },
    );
  }
}

typedef _VaultView = ({
  int count,
  bool hasFavorites,
  List<String> folders,
  List<VaultEntry> visible,
});

/// Klasör penceresinin sonucu: `null` klasörden çıkarır.
final class _FolderChoice {
  const new(this.folder);

  final String? folder;
}

/// Seçilenleri taşımak için klasör penceresi: var olan klasörler, yeni
/// klasör ve klasörden çıkarma.
class _FolderSheet extends StatefulWidget {
  const new({required this.folders, required this.matchAgainst});

  final List<String> folders;

  /// Yeni yazılan adın harf büyüklüğüyle eşleneceği klasörler.
  final List<String> matchAgainst;

  @override
  State<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<_FolderSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submitNew() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _FolderChoice(matchExistingFolder(name, widget.matchAgainst)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = KkGlass.of(context).accent;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.moveToFolder,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              for (final folder in widget.folders)
                ListTile(
                  leading: Icon(Icons.folder_outlined, color: accent),
                  title: Text(folder),
                  onTap: () => Navigator.pop(context, _FolderChoice(folder)),
                ),
              ListTile(
                leading: Icon(Icons.folder_off_outlined, color: accent),
                title: Text(l10n.folderRemove),
                onTap: () => Navigator.pop(context, const _FolderChoice(null)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SecretField(
                        controller: _name,
                        label: l10n.folderNew,
                        obscure: false,
                        plain: PlainKeyboard.text,
                        onSubmitted: (_) => _submitNew(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _name.text.trim().isEmpty ? null : _submitNew,
                      child: Text(l10n.folderMove),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boş kasa: "+" ipucu ve başka uygulamadan ya da eski telefondan gelen
/// kullanıcı için iki kısayol.
class _EmptyVault extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.vaultEmpty, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.input_rounded),
              label: Text(l10n.loginImportTitle),
              onPressed: () => unawaited(pickLoginExport(context, ref)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.settings_backup_restore_rounded),
              label: Text(l10n.restoreTitle),
              onPressed: () => unawaited(pickBackupToRestore(context, ref)),
            ),
          ],
        ),
      ],
    );
  }
}
