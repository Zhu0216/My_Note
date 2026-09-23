part of '../main.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width >= 720
          ? 260
          : (MediaQuery.sizeOf(context).width - 44) / 2,
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetricSummaryRow extends StatelessWidget {
  const MetricSummaryRow({
    super.key,
    required this.items,
    this.style = HomeSectionStyle.list,
    this.forceInline = false,
  });

  final List<MetricInfo> items;
  final HomeSectionStyle style;
  final bool forceInline;

  @override
  Widget build(BuildContext context) {
    if (forceInline) {
      return InfoCard(
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: MetricSummaryCell(item: items[index])),
              if (index != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      );
    }

    if (style == HomeSectionStyle.grid) {
      return HomeTileWrap(
        children: [
          for (final item in items)
            SizedBox(
              width: homeGridTileWidth(context),
              child: InfoCard(child: MetricSummaryCell(item: item)),
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InfoCard(child: MetricSummaryCell(item: item)),
          ),
      ],
    );
  }
}

class MetricSummaryCell extends StatelessWidget {
  const MetricSummaryCell({super.key, required this.item});

  final MetricInfo item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(item.icon, color: item.color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            item.value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.mode = NotesViewMode.list,
    this.selectable = false,
    this.selected = false,
    this.readOnly = false,
    this.onSelectionChanged,
    this.onDelete,
  });

  final NoteItem note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final NotesViewMode mode;
  final bool selectable;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final tile = Card(
      color: selected
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.65)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xffe1e5e1)),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: switch (mode) {
          NotesViewMode.grid => NoteGridContent(
            note: note,
            selectable: selectable,
            selected: selected,
            readOnly: readOnly,
            onSelectionChanged: onSelectionChanged,
            onTogglePinned: () => store.toggleNotePinned(note),
          ),
          NotesViewMode.list => NoteListContent(
            note: note,
            selectable: selectable,
            selected: selected,
            readOnly: readOnly,
            onSelectionChanged: onSelectionChanged,
            onTogglePinned: () => store.toggleNotePinned(note),
          ),
          NotesViewMode.compact => NoteCompactContent(
            note: note,
            selectable: selectable,
            selected: selected,
            readOnly: readOnly,
            onSelectionChanged: onSelectionChanged,
            onTogglePinned: () => store.toggleNotePinned(note),
          ),
        },
      ),
    );
    if (onDelete == null || selectable) {
      return tile;
    }
    return SwipeDeleteTile(
      itemKey: 'note-${note.id}',
      confirmTitle: '刪除筆記？',
      confirmMessage: '確定要刪除這筆筆記嗎？',
      onDelete: onDelete!,
      child: tile,
    );
  }
}

class NoteListContent extends StatelessWidget {
  const NoteListContent({
    super.key,
    required this.note,
    required this.selectable,
    required this.selected,
    required this.readOnly,
    required this.onSelectionChanged,
    required this.onTogglePinned,
  });

  final NoteItem note;
  final bool selectable;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onSelectionChanged;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: NoteSelectionOrIcon(
        selectable: selectable,
        selected: selected,
        onChanged: onSelectionChanged,
        icon: noteTemplateIcon(note.templateType),
      ),
      title: Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 72),
            child: Text(
              note.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          NoteMetaWrap(note: note),
        ],
      ),
      trailing: readOnly
          ? null
          : NotePinButton(note: note, onPressed: onTogglePinned),
    );
  }
}

class NoteGridContent extends StatelessWidget {
  const NoteGridContent({
    super.key,
    required this.note,
    required this.selectable,
    required this.selected,
    required this.readOnly,
    required this.onSelectionChanged,
    required this.onTogglePinned,
  });

  final NoteItem note;
  final bool selectable;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onSelectionChanged;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              NoteSelectionOrIcon(
                selectable: selectable,
                selected: selected,
                onChanged: onSelectionChanged,
                icon: noteTemplateIcon(note.templateType),
              ),
              const Spacer(),
              if (!readOnly)
                NotePinButton(
                  note: note,
                  onPressed: onTogglePinned,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (note.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (note.category.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

class NoteCompactContent extends StatelessWidget {
  const NoteCompactContent({
    super.key,
    required this.note,
    required this.selectable,
    required this.selected,
    required this.readOnly,
    required this.onSelectionChanged,
    required this.onTogglePinned,
  });

  final NoteItem note;
  final bool selectable;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onSelectionChanged;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NoteSelectionOrIcon(
            selectable: selectable,
            selected: selected,
            onChanged: onSelectionChanged,
            icon: noteTemplateIcon(note.templateType),
          ),
          const SizedBox(width: 8),
          NoteBodyThumbnail(body: note.body),
        ],
      ),
      title: Text(
        note.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: readOnly
          ? null
          : NotePinButton(note: note, onPressed: onTogglePinned),
    );
  }
}

class NoteSelectionOrIcon extends StatelessWidget {
  const NoteSelectionOrIcon({
    super.key,
    required this.selectable,
    required this.selected,
    required this.onChanged,
    required this.icon,
  });

  final bool selectable;
  final bool selected;
  final VoidCallback? onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!selectable) {
      return Icon(icon);
    }
    return Checkbox(
      value: selected,
      visualDensity: VisualDensity.compact,
      onChanged: (_) => onChanged?.call(),
    );
  }
}

class NotePinButton extends StatelessWidget {
  const NotePinButton({
    super.key,
    required this.note,
    required this.onPressed,
    this.dense = false,
  });

  final NoteItem note;
  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: note.isPinned ? '取消置頂' : '置頂',
      visualDensity: dense ? VisualDensity.compact : null,
      padding: dense ? EdgeInsets.zero : null,
      constraints: dense
          ? const BoxConstraints.tightFor(width: 32, height: 32)
          : null,
      onPressed: onPressed,
      icon: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
    );
  }
}

class NoteMetaWrap extends StatelessWidget {
  const NoteMetaWrap({super.key, required this.note});

  final NoteItem note;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (note.category.trim().isNotEmpty)
          Chip(
            label: Text(note.category),
            visualDensity: VisualDensity.compact,
          ),
        for (final tag in note.tags.take(3))
          Chip(label: Text('#$tag'), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class NoteBodyThumbnail extends StatelessWidget {
  const NoteBodyThumbnail({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final text = body.trim().isEmpty ? '...' : body.trim();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class BatchActionBar extends StatelessWidget {
  const BatchActionBar({
    super.key,
    required this.selectedCount,
    required this.canRename,
    required this.onDelete,
    required this.onMove,
    required this.onRename,
    required this.onDone,
  });

  final int selectedCount;
  final bool canRename;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final VoidCallback? onRename;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text('已選 $selectedCount 項')),
          FilledButton.tonalIcon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('刪除'),
          ),
          FilledButton.tonalIcon(
            onPressed: onMove,
            icon: const Icon(Icons.drive_file_move_outline),
            label: const Text('移動'),
          ),
          if (canRename)
            FilledButton.tonalIcon(
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('重新命名'),
            ),
          TextButton(onPressed: onDone, child: const Text('完成')),
        ],
      ),
    );
  }
}

class TrashBatchActionBar extends StatelessWidget {
  const TrashBatchActionBar({
    super.key,
    required this.selectedCount,
    required this.onRestore,
    required this.onDelete,
    required this.onDone,
  });

  final int selectedCount;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text('已選 $selectedCount 筆')),
          FilledButton.tonalIcon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore),
            label: const Text('復原'),
          ),
          FilledButton.tonalIcon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('刪除'),
          ),
          TextButton(onPressed: onDone, child: const Text('完成')),
        ],
      ),
    );
  }
}

class NotesSortOption {
  const NotesSortOption(this.field, this.direction);

  final NotesSortField field;
  final SortDirection direction;
}

class NotesSortSummary extends StatelessWidget {
  const NotesSortSummary({
    super.key,
    required this.sortField,
    required this.sortDirection,
    required this.viewMode,
    required this.selectedTemplates,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onTemplateToggled,
  });

  final NotesSortField sortField;
  final SortDirection sortDirection;
  final NotesViewMode viewMode;
  final Set<NoteTemplateType> selectedTemplates;
  final void Function(NotesSortField field, SortDirection direction)
  onSortChanged;
  final ValueChanged<NotesViewMode> onViewModeChanged;
  final ValueChanged<NoteTemplateType> onTemplateToggled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelMedium;
    final currentSortLabel =
        '${notesSortFieldLabel(sortField)} ${sortDirectionSymbol(sortDirection)}';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<NotesSortOption>(
          tooltip: '排序',
          onSelected: (option) => onSortChanged(option.field, option.direction),
          itemBuilder: (context) => [
            for (final field in NotesSortField.values)
              for (final direction in SortDirection.values)
                PopupMenuItem(
                  value: NotesSortOption(field, direction),
                  child: Row(
                    children: [
                      Icon(notesSortFieldIcon(field), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${notesSortFieldLabel(field)} ${sortDirectionSymbol(direction)}',
                        ),
                      ),
                      if (sortField == field && sortDirection == direction)
                        const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
          ],
          child: NotesToolbarDropdownChip(
            icon: notesSortFieldIcon(sortField),
            label: '排序：$currentSortLabel',
          ),
        ),
        PopupMenuButton<NotesViewMode>(
          tooltip: '檢視',
          onSelected: onViewModeChanged,
          itemBuilder: (context) => [
            for (final mode in NotesViewMode.values)
              PopupMenuItem(
                value: mode,
                child: Row(
                  children: [
                    Icon(notesViewModeIcon(mode), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(notesViewModeLabel(mode))),
                    if (viewMode == mode) const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
          ],
          child: NotesToolbarDropdownChip(
            icon: notesViewModeIcon(viewMode),
            label: '檢視：${notesViewModeLabel(viewMode)}',
          ),
        ),
        const SizedBox(width: 2),
        for (final type in NoteTemplateType.values)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onTemplateToggled(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selectedTemplates.contains(type)
                    ? colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorScheme.primary),
              ),
              child: Text(
                noteTemplateLabel(type),
                style: textStyle?.copyWith(
                  color: selectedTemplates.contains(type)
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NotesToolbarDropdownChip extends StatelessWidget {
  const NotesToolbarDropdownChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

String noteDateFilterLabel(NotesDateFilter filter) {
  return switch (filter) {
    NotesDateFilter.all => '全部',
    NotesDateFilter.oneDay => '過去 1 日',
    NotesDateFilter.sevenDays => '過去 7 日',
    NotesDateFilter.thirtyDays => '過去 30 日',
  };
}

String notesViewModeLabel(NotesViewMode mode) {
  return switch (mode) {
    NotesViewMode.grid => '格線',
    NotesViewMode.list => '清單',
    NotesViewMode.compact => '簡易清單',
  };
}

IconData notesViewModeIcon(NotesViewMode mode) {
  return switch (mode) {
    NotesViewMode.grid => Icons.grid_view,
    NotesViewMode.list => Icons.view_list,
    NotesViewMode.compact => Icons.view_headline,
  };
}

String notesSortFieldLabel(NotesSortField field) {
  return switch (field) {
    NotesSortField.createdAt => '建立日期',
    NotesSortField.updatedAt => '修改日期',
    NotesSortField.title => '名稱',
    NotesSortField.tag => '標籤',
  };
}

IconData notesSortFieldIcon(NotesSortField field) {
  return switch (field) {
    NotesSortField.createdAt => Icons.event_available_outlined,
    NotesSortField.updatedAt => Icons.history_outlined,
    NotesSortField.title => Icons.sort_by_alpha,
    NotesSortField.tag => Icons.sell_outlined,
  };
}

String sortDirectionSymbol(SortDirection direction) {
  return switch (direction) {
    SortDirection.ascending => '↑',
    SortDirection.descending => '↓',
  };
}
