import 'package:flutter/material.dart';

import '../../data/my_note_data.dart';
import '../../ui/app_store_scope.dart';
import '../../ui/basic_display.dart';
import '../../ui/display_components.dart';
import '../../ui/folder_names.dart';
import '../../ui/note_navigation_helpers.dart';
import '../../ui/prompt_dialogs.dart';
import '../../ui/shared_components.dart';

typedef NotesEditorLauncher =
    Future<void> Function(
      BuildContext context, {
      NoteItem? note,
      String initialFolder,
      String? returnFolder,
      NoteTemplateType initialTemplateType,
      bool readOnly,
    });

class NotesFeatureActions {
  const NotesFeatureActions({required this.editNote});

  final NotesEditorLauncher editNote;
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.actions});

  final NotesFeatureActions actions;

  @override
  State<NotesPage> createState() => NotesPageState();
}

class EqualMenuIcon extends StatelessWidget {
  const EqualMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++) ...[
              Container(
                width: 18,
                height: 2,
                decoration: BoxDecoration(
                  color: IconTheme.of(context).color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (index != 2) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class NotesNavigationDrawer extends StatefulWidget {
  const NotesNavigationDrawer({
    super.key,
    required this.selectedFolder,
    required this.showingTrash,
    required this.onAllNotes,
    required this.onFolderSelected,
    required this.onNoteSelected,
    required this.onTrash,
  });

  final String selectedFolder;
  final bool showingTrash;
  final VoidCallback onAllNotes;
  final ValueChanged<String> onFolderSelected;
  final ValueChanged<NoteItem> onNoteSelected;
  final VoidCallback onTrash;

  @override
  State<NotesNavigationDrawer> createState() => _NotesNavigationDrawerState();
}

class _NotesNavigationDrawerState extends State<NotesNavigationDrawer> {
  final Set<String> expandedFolders = {};
  bool uncategorizedExpanded = false;

  @override
  void initState() {
    super.initState();
    expandSelectedFolder();
  }

  @override
  void didUpdateWidget(covariant NotesNavigationDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFolder != widget.selectedFolder) {
      expandSelectedFolder();
    }
  }

  void expandSelectedFolder() {
    if (widget.selectedFolder.isEmpty) {
      uncategorizedExpanded = true;
      return;
    }
    if (widget.selectedFolder == '所有筆記') {
      return;
    }
    var current = normalizeFolderPath(widget.selectedFolder);
    while (current.isNotEmpty) {
      expandedFolders.add(current);
      current = folderParentPath(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final notes = store.visibleNotes;
    final rootFolders = store.folderPaths
        .where((folder) => folderParentPath(folder).isEmpty)
        .toList(growable: false);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Text(
                '筆記',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('所有筆記'),
              trailing: Text('${notes.length}'),
              selected: !widget.showingTrash && widget.selectedFolder == '所有筆記',
              onTap: () {
                Navigator.pop(context);
                widget.onAllNotes();
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text('資料夾'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 16),
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('未分類'),
              trailing: FolderExpandButton(
                expanded: uncategorizedExpanded,
                count: notes.where((note) => note.category.isEmpty).length,
                onPressed: notes.any((note) => note.category.isEmpty)
                    ? () => setState(
                        () => uncategorizedExpanded = !uncategorizedExpanded,
                      )
                    : null,
              ),
              selected: !widget.showingTrash && widget.selectedFolder.isEmpty,
              onTap: () {
                Navigator.pop(context);
                widget.onFolderSelected('');
              },
            ),
            if (uncategorizedExpanded)
              for (final note in notes.where((note) => note.category.isEmpty))
                NotesDrawerNoteTile(
                  note: note,
                  depth: 1,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNoteSelected(note);
                  },
                  onLongPress: () => showNoteNavActions(context, note),
                ),
            for (final folder in rootFolders)
              ...buildFolderBranch(context, store, notes, folder, 0),
            const Divider(height: 28),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('垃圾桶'),
              trailing: Text('${store.trashNotes.length}'),
              selected: widget.showingTrash,
              onTap: () {
                Navigator.pop(context);
                widget.onTrash();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildFolderBranch(
    BuildContext context,
    AppStore store,
    List<NoteItem> notes,
    String folder,
    int depth,
  ) {
    final childFolders = store.folderPaths
        .where((item) => folderParentPath(item) == folder)
        .toList(growable: false);
    final directNotes = notes
        .where((note) => note.category == folder)
        .toList(growable: false);
    final expanded = expandedFolders.contains(folder);
    final hasChildren = childFolders.isNotEmpty || directNotes.isNotEmpty;

    return [
      NotesDrawerFolderTile(
        folder: folder,
        depth: depth,
        expanded: expanded,
        canExpand: hasChildren,
        selected: !widget.showingTrash && widget.selectedFolder == folder,
        count: notes
            .where((note) => folderContains(folder, note.category))
            .length,
        onTap: () {
          Navigator.pop(context);
          widget.onFolderSelected(folder);
        },
        onToggle: hasChildren
            ? () => setState(() {
                if (expanded) {
                  expandedFolders.remove(folder);
                } else {
                  expandedFolders.add(folder);
                }
              })
            : null,
        onLongPress: () => showFolderNavActions(context, folder),
      ),
      if (expanded) ...[
        for (final childFolder in childFolders)
          ...buildFolderBranch(context, store, notes, childFolder, depth + 1),
        for (final note in directNotes)
          NotesDrawerNoteTile(
            note: note,
            depth: depth + 1,
            onTap: () {
              Navigator.pop(context);
              widget.onNoteSelected(note);
            },
            onLongPress: () => showNoteNavActions(context, note),
          ),
      ],
    ];
  }

  Future<void> showFolderNavActions(BuildContext context, String folder) async {
    final store = AppStoreScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重新命名'),
              onTap: () async {
                Navigator.pop(context);
                final name = await promptForFolderName(
                  context,
                  title: '重新命名',
                  label: '名稱',
                  initialValue: folderBaseName(folder),
                );
                if (name != null && name.trim().isNotEmpty) {
                  store.renameNoteFolder(folder, name);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移動'),
              onTap: () async {
                Navigator.pop(context);
                final target = await chooseFolder(
                  context,
                  store,
                  title: '移動',
                  excludedFolder: folder,
                  rootLabel: '根目錄',
                );
                if (target != null) {
                  store.moveNoteFolder(folder, target);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('刪除'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await confirmDelete(
                  context,
                  title: '刪除資料夾？',
                  message: '確定要刪除這個資料夾嗎？',
                );
                if (confirmed) {
                  store.deleteNoteFolder(folder);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showNoteNavActions(BuildContext context, NoteItem note) async {
    final store = AppStoreScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重新命名'),
              onTap: () async {
                Navigator.pop(context);
                final title = await promptForText(
                  context,
                  title: '重新命名',
                  label: '筆記標題',
                  initialValue: note.title,
                );
                if (title != null) {
                  store.renameNote(note, title);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移動'),
              onTap: () async {
                Navigator.pop(context);
                final target = await chooseFolder(context, store);
                if (target != null) {
                  store.moveNoteToFolder(note, target);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('刪除筆記'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await confirmDelete(
                  context,
                  title: '刪除筆記？',
                  message: '確定要刪除這筆筆記嗎？',
                );
                if (confirmed) {
                  store.deleteNote(note);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NotesDrawerFolderTile extends StatelessWidget {
  const NotesDrawerFolderTile({
    super.key,
    required this.folder,
    required this.depth,
    required this.expanded,
    required this.canExpand,
    required this.selected,
    required this.count,
    required this.onTap,
    required this.onToggle,
    required this.onLongPress,
  });

  final String folder;
  final int depth;
  final bool expanded;
  final bool canExpand;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + depth * 18, right: 16),
      leading: const Icon(Icons.folder_outlined),
      title: Text(folderBaseName(folder)),
      trailing: FolderExpandButton(
        expanded: expanded,
        count: count,
        onPressed: canExpand ? onToggle : null,
      ),
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class FolderExpandButton extends StatelessWidget {
  const FolderExpandButton({
    super.key,
    required this.expanded,
    required this.count,
    required this.onPressed,
  });

  final bool expanded;
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) {
      return Text('$count');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count'),
        const SizedBox(width: 4),
        IconButton(
          tooltip: expanded ? '收合資料夾' : '展開資料夾',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(
            expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
          ),
        ),
      ],
    );
  }
}

class NotesDrawerNoteTile extends StatelessWidget {
  const NotesDrawerNoteTile({
    super.key,
    required this.note,
    required this.depth,
    required this.onTap,
    required this.onLongPress,
  });

  final NoteItem note;
  final int depth;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: 44 + depth * 18, right: 16),
      leading: Icon(
        note.isPinned ? Icons.push_pin : Icons.description_outlined,
        size: 18,
      ),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class NotesPageState extends State<NotesPage>
    with SingleTickerProviderStateMixin {
  String query = '';
  String folder = '所有筆記';
  NotesDateFilter dateFilter = NotesDateFilter.all;
  NotesSortField sortField = NotesSortField.updatedAt;
  SortDirection sortDirection = SortDirection.descending;
  NotesViewMode viewMode = NotesViewMode.list;
  final Set<NoteTemplateType> templateFilters = {};
  bool showFilters = false;
  bool batchMode = false;
  bool showingTrash = false;
  bool addMenuOpen = false;
  final Set<String> selectedNoteIds = {};
  final Set<String> selectedFolderPaths = {};
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController addFabController;

  @override
  void initState() {
    super.initState();
    addFabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    addFabController.dispose();
    super.dispose();
  }

  void toggleAddMenu() {
    if (addMenuOpen) {
      closeAddMenu();
    } else {
      setState(() => addMenuOpen = true);
      addFabController.forward();
    }
  }

  void closeAddMenu() {
    if (!addMenuOpen) {
      return;
    }
    setState(() => addMenuOpen = false);
    addFabController.reverse();
  }

  Future<void> handleAddMenu(String value) async {
    closeAddMenu();
    final templateType = noteTemplateTypeFromMenuValue(value);
    if (templateType != null) {
      await widget.actions.editNote(
        context,
        initialFolder: currentFolderContext,
        returnFolder: folder,
        initialTemplateType: templateType,
      );
    }
  }

  String get currentFolderContext {
    if (showingTrash || folder == '所有筆記') {
      return '';
    }
    return folder;
  }

  void openBackTarget(String value, {bool showTrash = false}) {
    setState(() {
      showingTrash = showTrash;
      folder = showTrash ? '所有筆記' : value;
      batchMode = false;
      showFilters = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
    });
    closeAddMenu();
  }

  bool handleAppBack() {
    if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
      scaffoldKey.currentState?.closeDrawer();
      return true;
    }
    if (addMenuOpen) {
      closeAddMenu();
      return true;
    }
    if (batchMode) {
      setState(() {
        batchMode = false;
        selectedNoteIds.clear();
        selectedFolderPaths.clear();
      });
      return true;
    }
    if (showFilters) {
      setState(() => showFilters = false);
      return true;
    }
    final target = notesBackTarget(folder, showingTrash: showingTrash);
    if (target == null) {
      return false;
    }
    openBackTarget(target);
    return true;
  }

  String get currentDirectoryTitle {
    if (showingTrash) {
      return '垃圾桶';
    }
    if (folder == '所有筆記') {
      return '所有筆記';
    }
    if (folder.isEmpty) {
      return '未分類';
    }
    return folder.replaceAll('/', '\\');
  }

  void openNotesFolder(String value) {
    setState(() {
      showingTrash = false;
      folder = value;
      batchMode = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
    });
  }

  Widget buildDirectoryTitle(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800);
    final linkStyle = titleStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    );
    final separatorStyle = titleStyle?.copyWith(color: Colors.black38);

    Widget separator() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Text('\\', style: separatorStyle),
      );
    }

    Widget item(
      String label,
      String target, {
      IconData? icon,
      bool iconOnly = false,
    }) {
      final isCurrent = !showingTrash && !batchMode && folder == target;
      final style = isCurrent ? titleStyle : linkStyle;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openNotesFolder(target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: style?.color ?? Theme.of(context).iconTheme.color,
                ),
                if (!iconOnly) const SizedBox(width: 4),
              ],
              if (!iconOnly)
                Text(
                  folderNameForPathTitle(label),
                  style: style,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
        ),
      );
    }

    if (showingTrash) {
      return Text(currentDirectoryTitle, style: titleStyle);
    }
    if (folder == '所有筆記') {
      return item('所有筆記', '所有筆記');
    }
    final children = <Widget>[
      item('所有筆記', '所有筆記', icon: Icons.library_books_outlined, iconOnly: true),
    ];
    if (folder.isEmpty) {
      children
        ..add(separator())
        ..add(item('未分類', '', icon: Icons.folder_open_outlined));
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );
    }

    final parts = normalizeFolderPath(folder).split('/');
    for (var index = 0; index < parts.length; index++) {
      final target = parts.take(index + 1).join('/');
      children
        ..add(separator())
        ..add(item(parts[index], target, icon: Icons.folder_outlined));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final folders = ['所有筆記', '', ...store.folderPaths];
    var notes = (showingTrash ? store.trashNotes : store.visibleNotes).where((
      note,
    ) {
      final text =
          '${note.title} ${note.body} ${note.category} ${note.tags.join(' ')}'
              .toLowerCase();
      return text.contains(query.toLowerCase()) &&
          (showingTrash ||
              folder == '所有筆記' ||
              noteBelongsToFolder(note.category, folder)) &&
          (templateFilters.isEmpty ||
              templateFilters.contains(note.templateType)) &&
          matchesDateFilter(note, dateFilter);
    }).toList();
    notes.sort(compareNotes);
    final pinnedNotes = showingTrash
        ? <NoteItem>[]
        : notes.where((note) => note.isPinned).toList();
    final regularNotes = showingTrash
        ? notes
        : notes.where((note) => !note.isPinned).toList();
    final childFolders = directChildFolders(store.folderPaths);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: NotesNavigationDrawer(
        selectedFolder: folder,
        showingTrash: showingTrash,
        onAllNotes: () => setState(() {
          showingTrash = false;
          folder = '所有筆記';
          batchMode = false;
          selectedNoteIds.clear();
          selectedFolderPaths.clear();
        }),
        onFolderSelected: (value) => setState(() {
          showingTrash = false;
          folder = value;
          batchMode = false;
          selectedNoteIds.clear();
          selectedFolderPaths.clear();
        }),
        onNoteSelected: (note) => widget.actions.editNote(context, note: note),
        onTrash: () => setState(() {
          showingTrash = true;
          batchMode = false;
          selectedNoteIds.clear();
          selectedFolderPaths.clear();
        }),
      ),
      floatingActionButton: showingTrash
          ? null
          : FloatingActionMenu(
              isOpen: addMenuOpen,
              controller: addFabController,
              tooltip: '新增筆記',
              onToggle: toggleAddMenu,
              heroTag: 'notes-add',
              items: [
                FloatingActionMenuItem(
                  icon: Icons.notes,
                  label: '筆記',
                  value: noteTemplateMenuValue(NoteTemplateType.general),
                  onSelected: handleAddMenu,
                ),
                FloatingActionMenuItem(
                  icon: Icons.flag_outlined,
                  label: '計劃',
                  value: noteTemplateMenuValue(NoteTemplateType.plan),
                  onSelected: handleAddMenu,
                ),
                FloatingActionMenuItem(
                  icon: Icons.account_tree_outlined,
                  label: '心智圖',
                  value: noteTemplateMenuValue(NoteTemplateType.mindMap),
                  onSelected: handleAddMenu,
                ),
                FloatingActionMenuItem(
                  icon: Icons.stacked_bar_chart,
                  label: '人生試算表',
                  value: noteTemplateMenuValue(NoteTemplateType.lifeSheet),
                  onSelected: handleAddMenu,
                ),
              ],
            ),
      body: DismissFabMenuLayer(
        isOpen: addMenuOpen,
        onDismiss: closeAddMenu,
        child: AppPage(
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: '開啟側邊欄',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const EqualMenuIcon(),
            ),
          ),
          title: currentDirectoryTitle,
          titleWidget: buildDirectoryTitle(context),
          subtitle: '資料夾、標籤與搜尋',
          actions: [
            IconButton(
              tooltip: '搜尋與篩選',
              onPressed: () => setState(() => showFilters = !showFilters),
              icon: Icon(showFilters ? Icons.search_off : Icons.search),
            ),
            if (showingTrash)
              IconButton(
                tooltip: '清空垃圾桶',
                onPressed: clearTrashNotes,
                icon: const Icon(Icons.delete_sweep_outlined),
              )
            else
              IconButton(
                tooltip: '建立資料夾',
                onPressed: createFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
          ],
          child: Column(
            children: [
              if (batchMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: showingTrash
                      ? TrashBatchActionBar(
                          selectedCount: selectedNoteIds.length,
                          onRestore: selectedNoteIds.isEmpty
                              ? null
                              : () => restoreSelectedTrashNotes(store),
                          onDelete: selectedNoteIds.isEmpty
                              ? null
                              : () =>
                                    permanentlyDeleteSelectedTrashNotes(store),
                          onDone: exitBatchMode,
                        )
                      : BatchActionBar(
                          selectedCount: selectedItemCount,
                          canRename: selectedItemCount == 1,
                          onDelete: selectedItemCount == 0
                              ? null
                              : () => deleteSelectedItems(store),
                          onMove: selectedItemCount == 0
                              ? null
                              : () => moveSelectedItems(store),
                          onRename: selectedItemCount == 1
                              ? () => renameSelectedItem(store)
                              : null,
                          onDone: exitBatchMode,
                        ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    if (showFilters) ...[
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '搜尋標題、內文、標籤',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setState(() => query = value),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          DropdownMenu<String>(
                            initialSelection: folder,
                            label: const Text('資料夾'),
                            dropdownMenuEntries: folders
                                .map(
                                  (item) => DropdownMenuEntry(
                                    value: item,
                                    label: item.isEmpty ? '未分類' : item,
                                  ),
                                )
                                .toList(),
                            onSelected: (value) =>
                                setState(() => folder = value ?? '所有筆記'),
                          ),
                          DropdownMenu<NotesDateFilter>(
                            initialSelection: dateFilter,
                            label: const Text('日期篩選'),
                            dropdownMenuEntries: NotesDateFilter.values
                                .map(
                                  (item) => DropdownMenuEntry(
                                    value: item,
                                    label: noteDateFilterLabel(item),
                                  ),
                                )
                                .toList(),
                            onSelected: (value) => setState(
                              () => dateFilter = value ?? NotesDateFilter.all,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    NotesSortSummary(
                      sortField: sortField,
                      sortDirection: sortDirection,
                      viewMode: viewMode,
                      selectedTemplates: templateFilters,
                      onSortChanged: (field, direction) {
                        setState(() {
                          sortField = field;
                          sortDirection = direction;
                        });
                      },
                      onViewModeChanged: (mode) =>
                          setState(() => viewMode = mode),
                      onTemplateToggled: (type) {
                        setState(() {
                          if (!templateFilters.add(type)) {
                            templateFilters.remove(type);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (notes.isEmpty && childFolders.isEmpty)
                      EmptyState(
                        icon: Icons.note_alt_outlined,
                        text: showingTrash ? '垃圾桶沒有筆記' : '還沒有筆記',
                      )
                    else ...[
                      if (childFolders.isNotEmpty)
                        NotesFolderGrid(
                          folders: childFolders,
                          selectedFolders: selectedFolderPaths,
                          onTap: handleFolderTap,
                          onLongPress: enterBatchModeWithFolder,
                        ),
                      if (pinnedNotes.isNotEmpty)
                        NotesGroupContainer(
                          notes: pinnedNotes,
                          mode: viewMode,
                          batchMode: batchMode,
                          selectedNoteIds: selectedNoteIds,
                          onSelectionChanged: toggleSelected,
                          onTap: handleNoteTap,
                          onLongPress: enterBatchModeWith,
                          readOnly: showingTrash,
                          onDelete: showingTrash
                              ? null
                              : (note) => store.deleteNote(note),
                        ),
                      if (regularNotes.isNotEmpty)
                        NotesGroupContainer(
                          notes: regularNotes,
                          mode: viewMode,
                          batchMode: batchMode,
                          selectedNoteIds: selectedNoteIds,
                          onSelectionChanged: toggleSelected,
                          onTap: handleNoteTap,
                          onLongPress: enterBatchModeWith,
                          readOnly: showingTrash,
                          onDelete: showingTrash
                              ? null
                              : (note) => store.deleteNote(note),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> directChildFolders(List<String> folders) {
    if (showingTrash || folder.isEmpty) {
      return [];
    }
    if (folder == '所有筆記') {
      return folders
          .where((item) => folderParentPath(item).isEmpty)
          .toList(growable: false);
    }
    final current = normalizeFolderPath(folder);
    return folders
        .where((item) => folderParentPath(item) == current)
        .toList(growable: false);
  }

  int compareNotes(NoteItem a, NoteItem b) {
    int result;
    switch (sortField) {
      case NotesSortField.createdAt:
        result = a.createdAt.compareTo(b.createdAt);
        break;
      case NotesSortField.updatedAt:
        result = a.updatedAt.compareTo(b.updatedAt);
        break;
      case NotesSortField.title:
        result = a.title.compareTo(b.title);
        break;
      case NotesSortField.tag:
        result = firstTag(a).compareTo(firstTag(b));
        break;
    }
    if (result == 0 && a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }
    return sortDirection == SortDirection.ascending ? result : -result;
  }

  String firstTag(NoteItem note) => note.tags.isEmpty ? '' : note.tags.first;

  int get selectedItemCount =>
      selectedNoteIds.length + selectedFolderPaths.length;

  bool matchesDateFilter(NoteItem note, NotesDateFilter filter) {
    if (filter == NotesDateFilter.all) {
      return true;
    }
    final now = DateTime.now();
    final days = switch (filter) {
      NotesDateFilter.oneDay => 1,
      NotesDateFilter.sevenDays => 7,
      NotesDateFilter.thirtyDays => 30,
      NotesDateFilter.all => 0,
    };
    return note.updatedAt.isAfter(now.subtract(Duration(days: days)));
  }

  void handleNoteTap(NoteItem note) {
    if (batchMode) {
      toggleSelected(note);
      return;
    }
    widget.actions.editNote(context, note: note, readOnly: showingTrash);
  }

  void handleFolderTap(String targetFolder) {
    if (batchMode) {
      toggleSelectedFolder(targetFolder);
      return;
    }
    openNotesFolder(targetFolder);
  }

  void enterBatchModeWith(NoteItem note) {
    setState(() {
      if (!batchMode) {
        selectedNoteIds.clear();
        selectedFolderPaths.clear();
      }
      batchMode = true;
      selectedNoteIds.add(note.id);
    });
  }

  void enterBatchModeWithFolder(String targetFolder) {
    setState(() {
      if (!batchMode) {
        selectedNoteIds.clear();
        selectedFolderPaths.clear();
      }
      batchMode = true;
      selectedFolderPaths.add(targetFolder);
    });
  }

  void exitBatchMode() {
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
    });
  }

  void toggleSelected(NoteItem note) {
    setState(() {
      if (!selectedNoteIds.add(note.id)) {
        selectedNoteIds.remove(note.id);
      }
      if (selectedItemCount == 0) {
        batchMode = false;
      }
    });
  }

  void toggleSelectedFolder(String targetFolder) {
    setState(() {
      if (!selectedFolderPaths.add(targetFolder)) {
        selectedFolderPaths.remove(targetFolder);
      }
      if (selectedItemCount == 0) {
        batchMode = false;
      }
    });
  }

  Future<void> showNotesOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (showingTrash) ...[
              ListTile(
                leading: Icon(batchMode ? Icons.close : Icons.checklist),
                title: Text(batchMode ? '完成編輯' : '編輯'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    batchMode = !batchMode;
                    selectedNoteIds.clear();
                    selectedFolderPaths.clear();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('刪除全部'),
                onTap: () {
                  Navigator.pop(context);
                  clearTrashNotes();
                },
              ),
            ] else
              ListTile(
                leading: Icon(batchMode ? Icons.close : Icons.checklist),
                title: Text(batchMode ? '完成編輯' : '編輯'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    batchMode = !batchMode;
                    selectedNoteIds.clear();
                    selectedFolderPaths.clear();
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('檢視'),
              subtitle: Text(notesViewModeLabel(viewMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                showNotesViewOptions(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert),
              title: const Text('排序'),
              subtitle: Text(
                '${notesSortFieldLabel(sortField)}'
                ' ${sortDirectionSymbol(sortDirection)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                showNotesSortOptions(context);
              },
            ),
            if (!showingTrash)
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('建立資料夾'),
                onTap: () {
                  Navigator.pop(context);
                  createFolder();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> clearTrashNotes() async {
    final store = AppStoreScope.of(context);
    if (store.trashNotes.isEmpty) {
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: '刪除全部？',
      message: '確定要清空垃圾桶嗎？',
    );
    if (!confirmed || !mounted) {
      return;
    }
    store.clearTrashNotes();
  }

  Future<void> showNotesViewOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            SheetBackHeader(
              title: '檢視',
              onBack: () {
                Navigator.pop(context);
                Future<void>.delayed(const Duration(milliseconds: 180), () {
                  if (mounted) {
                    showNotesOptions(this.context);
                  }
                });
              },
            ),
            for (final mode in NotesViewMode.values)
              ListTile(
                leading: Icon(notesViewModeIcon(mode)),
                title: Text(notesViewModeLabel(mode)),
                trailing: viewMode == mode ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => viewMode = mode);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> showNotesSortOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            SheetBackHeader(
              title: '排序',
              onBack: () {
                Navigator.pop(context);
                Future<void>.delayed(const Duration(milliseconds: 180), () {
                  if (mounted) {
                    showNotesOptions(this.context);
                  }
                });
              },
            ),
            for (final field in NotesSortField.values)
              for (final direction in SortDirection.values)
                ListTile(
                  leading: Icon(notesSortFieldIcon(field)),
                  title: Text(
                    '${notesSortFieldLabel(field)}'
                    ' ${sortDirectionSymbol(direction)}',
                  ),
                  trailing: sortField == field && sortDirection == direction
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      sortField = field;
                      sortDirection = direction;
                    });
                  },
                ),
          ],
        ),
      ),
    );
  }

  Future<void> createFolder() async {
    final store = AppStoreScope.of(context);
    final name = await promptForFolderName(
      context,
      title: '新增資料夾',
      label: '資料夾名稱',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final newFolder = joinFolderPath(
      currentFolderContext,
      limitFolderNameForStorage(name),
    );
    store.createNoteFolder(newFolder);
    setState(() {
      showingTrash = false;
      folder = newFolder;
      batchMode = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
    });
  }

  Future<void> showFolderActions(String targetFolder) async {
    final store = AppStoreScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重新命名'),
              onTap: () async {
                Navigator.pop(context);
                final name = await promptForFolderName(
                  this.context,
                  title: '重新命名',
                  label: '名稱',
                  initialValue: folderBaseName(targetFolder),
                );
                if (name != null && name.trim().isNotEmpty) {
                  store.renameNoteFolder(targetFolder, name);
                  setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移動'),
              onTap: () async {
                Navigator.pop(context);
                final target = await chooseFolder(
                  this.context,
                  store,
                  title: '移動',
                  excludedFolder: targetFolder,
                  rootLabel: '根目錄',
                );
                if (target != null) {
                  store.moveNoteFolder(targetFolder, target);
                  setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('刪除'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await confirmDelete(
                  this.context,
                  title: '刪除資料夾？',
                  message: '確定要刪除這個資料夾嗎？',
                );
                if (confirmed) {
                  store.deleteNoteFolder(targetFolder);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteSelectedItems(AppStore store) async {
    final confirmed = await confirmDelete(
      context,
      title: '刪除選取項目？',
      message: '確定要刪除選取的筆記與資料夾嗎？',
    );
    if (!confirmed) {
      return;
    }
    final deletingFolders = selectedFolderPaths.toList(growable: false);
    final shouldLeaveFolder = deletingFolders.any(
      (item) =>
          normalizeFolderPath(folder) == normalizeFolderPath(item) ||
          folderContains(item, folder),
    );
    if (selectedNoteIds.isNotEmpty) {
      store.deleteNotesById(selectedNoteIds);
    }
    for (final folderPath in deletingFolders) {
      store.deleteNoteFolder(folderPath);
    }
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
      if (shouldLeaveFolder) {
        folder = '所有筆記';
      }
    });
  }

  void restoreSelectedTrashNotes(AppStore store) {
    store.restoreNotesById(selectedNoteIds);
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
    });
  }

  Future<void> permanentlyDeleteSelectedTrashNotes(AppStore store) async {
    final confirmed = await confirmDelete(
      context,
      title: '刪除選取筆記？',
      message: '這會永久刪除垃圾桶中選取的筆記，確定要刪除嗎？',
    );
    if (!confirmed || !mounted) {
      return;
    }
    store.permanentlyDeleteNotesById(selectedNoteIds);
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
    });
  }

  Future<void> moveSelectedItems(AppStore store) async {
    final folderName = await chooseFolder(
      context,
      store,
      excludedFolder: selectedFolderPaths.length == 1
          ? selectedFolderPaths.single
          : '',
    );
    if (folderName == null) {
      return;
    }
    if (selectedNoteIds.isNotEmpty) {
      store.moveNotesToFolder(selectedNoteIds, folderName);
    }
    for (final folderPath in selectedFolderPaths) {
      store.moveNoteFolder(folderPath, folderName);
    }
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
      folder = folderName;
    });
  }

  Future<void> renameSelectedItem(AppStore store) async {
    if (selectedFolderPaths.length == 1 && selectedNoteIds.isEmpty) {
      final targetFolder = selectedFolderPaths.single;
      final name = await promptForFolderName(
        context,
        title: '重新命名',
        label: '資料夾名稱',
        initialValue: folderBaseName(targetFolder),
      );
      if (name == null || name.trim().isEmpty) {
        return;
      }
      final newPath = joinFolderPath(
        folderParentPath(targetFolder),
        limitFolderNameForStorage(name),
      );
      store.renameNoteFolder(targetFolder, name);
      setState(() {
        batchMode = false;
        selectedFolderPaths.clear();
        if (folderContains(targetFolder, folder) ||
            normalizeFolderPath(folder) == normalizeFolderPath(targetFolder)) {
          folder = replaceFolderPrefix(folder, targetFolder, newPath);
        }
      });
      return;
    }

    final note = store.notes.firstWhere(
      (item) => item.id == selectedNoteIds.first,
    );
    final title = await promptForText(
      context,
      title: '重新命名',
      label: '筆記標題',
      initialValue: note.title,
    );
    if (title == null) {
      return;
    }
    store.renameNote(note, title);
    setState(() {
      batchMode = false;
      selectedNoteIds.clear();
      selectedFolderPaths.clear();
    });
  }
}

class NotesGroupContainer extends StatelessWidget {
  const NotesGroupContainer({
    super.key,
    required this.notes,
    required this.mode,
    required this.batchMode,
    required this.selectedNoteIds,
    required this.onSelectionChanged,
    required this.onTap,
    required this.onLongPress,
    this.readOnly = false,
    this.onDelete,
  });

  final List<NoteItem> notes;
  final NotesViewMode mode;
  final bool batchMode;
  final Set<String> selectedNoteIds;
  final ValueChanged<NoteItem> onSelectionChanged;
  final ValueChanged<NoteItem> onTap;
  final ValueChanged<NoteItem> onLongPress;
  final bool readOnly;
  final ValueChanged<NoteItem>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdfe6df)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode == NotesViewMode.grid)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < 3; column++) ...[
                  if (column > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = column;
                          index < notes.length;
                          index += 3
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: buildTile(notes[index]),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            )
          else
            for (var index = 0; index < notes.length; index++) ...[
              buildTile(notes[index]),
              if (index != notes.length - 1)
                const Divider(
                  height: 16,
                  thickness: 0.8,
                  color: Color(0xffe1e5e1),
                ),
            ],
        ],
      ),
    );
  }

  Widget buildTile(NoteItem note) {
    return NoteTile(
      note: note,
      mode: mode,
      selectable: batchMode,
      selected: selectedNoteIds.contains(note.id),
      onSelectionChanged: () => onSelectionChanged(note),
      onTap: () => onTap(note),
      onLongPress: () => onLongPress(note),
      readOnly: readOnly,
      onDelete: onDelete == null ? null : () => onDelete!(note),
    );
  }
}

class NotesFolderGrid extends StatelessWidget {
  const NotesFolderGrid({
    super.key,
    required this.folders,
    required this.selectedFolders,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String> folders;
  final Set<String> selectedFolders;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdfe6df)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final folder in folders)
              Builder(
                builder: (context) {
                  final selected = selectedFolders.contains(folder);
                  return SizedBox(
                    width: 72,
                    child: Material(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: 0.72)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onTap(folder),
                        onLongPress: () => onLongPress(folder),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 28,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                limitedFolderNameForDisplay(
                                  folderBaseName(folder),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
