import 'dart:math' as math;

import 'package:flutter/material.dart';

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.titleWidget,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? titleWidget;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffe1e6f3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: leading!,
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget ??
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xff171f2f),
                              ),
                        ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xff687386),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      onPressed: onPressed ?? () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back),
    );
  }
}

class EditorActionButtons extends StatelessWidget {
  const EditorActionButtons({
    super.key,
    required this.onCancel,
    required this.onSave,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            label: const Text('取消'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save),
            label: const Text('儲存'),
          ),
        ),
      ],
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xffe4e8f5)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class AddBubbleButton extends StatelessWidget {
  const AddBubbleButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.heroTag,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      shape: const CircleBorder(),
      tooltip: tooltip,
      onPressed: onPressed,
      child: const Icon(Icons.add),
    );
  }
}

class AnimatedQuickAddFab extends StatelessWidget {
  const AnimatedQuickAddFab({
    super.key,
    required this.tooltip,
    required this.controller,
    required this.onPressed,
    this.heroTag,
  });

  final String tooltip;
  final AnimationController controller;
  final VoidCallback onPressed;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return FloatingActionButton(
          heroTag: heroTag,
          shape: const CircleBorder(),
          tooltip: tooltip,
          onPressed: onPressed,
          child: Transform.rotate(
            angle: controller.value * math.pi * 0.75,
            child: child,
          ),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}

class FloatingActionMenuItem {
  const FloatingActionMenuItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String value;
  final ValueChanged<String> onSelected;
}

class DismissFabMenuLayer extends StatelessWidget {
  const DismissFabMenuLayer({
    super.key,
    required this.isOpen,
    required this.onDismiss,
    required this.child,
  });

  final bool isOpen;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isOpen)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => onDismiss(),
            ),
          ),
      ],
    );
  }
}

class FloatingActionMenu extends StatelessWidget {
  const FloatingActionMenu({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.tooltip,
    required this.onToggle,
    required this.items,
    this.heroTag,
  });

  final bool isOpen;
  final AnimationController controller;
  final String tooltip;
  final VoidCallback onToggle;
  final List<FloatingActionMenuItem> items;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IgnorePointer(
          ignoring: !isOpen,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isOpen
                ? Column(
                    key: const ValueKey('fab-menu-open'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        FloatingActionMenuPill(
                          key: ValueKey(items[index].value),
                          item: items[index],
                          index: index,
                          totalCount: items.length,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('fab-menu-closed')),
          ),
        ),
        AnimatedQuickAddFab(
          tooltip: tooltip,
          controller: controller,
          onPressed: onToggle,
          heroTag: heroTag,
        ),
      ],
    );
  }
}

class FloatingActionMenuPill extends StatefulWidget {
  const FloatingActionMenuPill({
    super.key,
    required this.item,
    required this.index,
    required this.totalCount,
  });

  final FloatingActionMenuItem item;
  final int index;
  final int totalCount;

  @override
  State<FloatingActionMenuPill> createState() => _FloatingActionMenuPillState();
}

class _FloatingActionMenuPillState extends State<FloatingActionMenuPill> {
  bool visible = false;

  @override
  void initState() {
    super.initState();
    final delayIndex = widget.totalCount - widget.index - 1;
    Future<void>.delayed(Duration(milliseconds: delayIndex * 100), () {
      if (mounted) {
        setState(() => visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0.5,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: Offset(visible ? 0 : 0.26, 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: Material(
          color: colorScheme.surface,
          elevation: 7,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => widget.item.onSelected(widget.item.value),
            child: Container(
              width: 190,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.72),
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.item.icon, size: 22, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuickAddPanel extends StatelessWidget {
  const QuickAddPanel({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '快速新增',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              QuickAddOption(
                icon: Icons.notes,
                title: '新增筆記',
                value: 'note',
                onSelected: onSelected,
              ),
              QuickAddOption(
                icon: Icons.add_task,
                title: '新增待辦事項',
                value: 'todo',
                onSelected: onSelected,
              ),
              QuickAddOption(
                icon: Icons.payments_outlined,
                title: '新增記帳',
                value: 'finance',
                onSelected: onSelected,
              ),
              QuickAddOption(
                icon: Icons.subscriptions_outlined,
                title: '新增訂閱費用',
                value: 'subscription',
                onSelected: onSelected,
              ),
              QuickAddOption(
                icon: Icons.event_note,
                title: '新增行程',
                value: 'schedule',
                onSelected: onSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickAddOption extends StatelessWidget {
  const QuickAddOption({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onSelected,
  });

  final IconData icon;
  final String title;
  final String value;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onSelected(value),
    );
  }
}

class SwipeDeleteTile extends StatefulWidget {
  const SwipeDeleteTile({
    super.key,
    required this.itemKey,
    required this.child,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onDelete,
  });

  final String itemKey;
  final Widget child;
  final String confirmTitle;
  final String confirmMessage;
  final VoidCallback onDelete;

  @override
  State<SwipeDeleteTile> createState() => _SwipeDeleteTileState();
}

class _SwipeDeleteTileState extends State<SwipeDeleteTile> {
  static const double actionWidth = 88;

  double dragOffset = 0;

  bool get isOpen => dragOffset <= -actionWidth / 2;

  void settle() {
    setState(() {
      dragOffset = isOpen ? -actionWidth : 0;
    });
  }

  @override
  void didUpdateWidget(covariant SwipeDeleteTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemKey != widget.itemKey && dragOffset != 0) {
      dragOffset = 0;
    }
  }

  Future<void> requestDelete() async {
    final confirmed = await confirmDelete(
      context,
      title: widget.confirmTitle,
      message: widget.confirmMessage,
    );
    if (!mounted) {
      return;
    }
    if (confirmed) {
      setState(() => dragOffset = 0);
      widget.onDelete();
    } else {
      setState(() => dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              setState(() {
                dragOffset = (dragOffset + details.delta.dx).clamp(
                  -actionWidth,
                  0.0,
                );
              });
            },
            onHorizontalDragEnd: (_) => settle(),
            onTap: () {
              if (dragOffset != 0) {
                setState(() => dragOffset = 0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(dragOffset, 0, 0),
              child: widget.child,
            ),
          ),
          if (dragOffset < 0)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: actionWidth,
              child: Material(
                color: Colors.red.shade700,
                child: InkWell(
                  onTap: requestDelete,
                  child: const Center(
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.delete),
          label: const Text('刪除'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmSaveChanges(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('不儲存'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.save_outlined),
          label: const Text('儲存'),
        ),
      ],
    ),
  );
  return result ?? true;
}
