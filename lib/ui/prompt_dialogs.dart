import 'package:flutter/material.dart';

import '../data/my_note_data.dart';
import 'folder_names.dart';

Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => StableTextPromptDialog(
      title: title,
      label: label,
      initialValue: initialValue,
    ),
  );
}

Future<String?> promptForFolderName(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => StableFolderNamePromptDialog(
      title: title,
      label: label,
      initialValue: initialValue,
    ),
  );
}

class StableTextPromptDialog extends StatefulWidget {
  const StableTextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    this.initialValue = '',
  });

  final String title;
  final String label;
  final String initialValue;

  @override
  State<StableTextPromptDialog> createState() => _StableTextPromptDialogState();
}

class _StableTextPromptDialogState extends State<StableTextPromptDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    Navigator.of(context).pop(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: submit, child: const Text('確認')),
      ],
    );
  }
}

class StableFolderNamePromptDialog extends StatefulWidget {
  const StableFolderNamePromptDialog({
    super.key,
    required this.title,
    required this.label,
    this.initialValue = '',
  });

  final String title;
  final String label;
  final String initialValue;

  @override
  State<StableFolderNamePromptDialog> createState() =>
      _StableFolderNamePromptDialogState();
}

class _StableFolderNamePromptDialogState
    extends State<StableFolderNamePromptDialog> {
  late final TextEditingController controller;
  bool limitExceeded = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: limitFolderNameForStorage(widget.initialValue),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void updateLimitExceeded(String value) {
    final exceeded = !folderNameWithinLengthLimit(value);
    if (limitExceeded != exceeded) {
      setState(() => limitExceeded = exceeded);
    }
  }

  void submit() {
    final value = controller.text.trim();
    if (!folderNameWithinLengthLimit(value)) {
      if (!limitExceeded) {
        setState(() => limitExceeded = true);
      }
      return;
    }
    Navigator.of(context).pop(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: '最多 18 個半形字或 12 個全形字',
          errorText: limitExceeded ? '資料夾名稱已達長度上限' : null,
        ),
        onChanged: updateLimitExceeded,
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: limitExceeded ? null : submit,
          child: const Text('確認'),
        ),
      ],
    );
  }
}

Future<String?> chooseFolder(
  BuildContext context,
  AppStore store, {
  String title = '選擇資料夾',
  String excludedFolder = '',
  String rootLabel = '未分類',
}) async {
  final excluded = normalizeFolderPath(excludedFolder);
  final folders =
      store.folderPaths
          .where(
            (folder) => excluded.isEmpty || !folderContains(excluded, folder),
          )
          .toList()
        ..sort();
  var currentFolder = '';
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocalState) {
        final childFolders = folders
            .where((folder) => folderParentPath(folder) == currentFolder)
            .toList(growable: false);
        final canGoBack = currentFolder.isNotEmpty;
        final currentLabel = currentFolder.isEmpty
            ? rootLabel
            : folderBaseName(currentFolder);
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        currentFolder.isEmpty
                            ? Icons.folder_open_outlined
                            : Icons.folder_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentFolder.isEmpty
                              ? rootLabel
                              : currentFolder.replaceAll('/', '\\'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (canGoBack)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_back),
                            title: const Text('上一層'),
                            onTap: () => setLocalState(
                              () => currentFolder = folderParentPath(
                                currentFolder,
                              ),
                            ),
                          ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text('移到這裡'),
                          subtitle: Text(currentLabel),
                          onTap: () => Navigator.pop(context, currentFolder),
                        ),
                        const Divider(height: 16),
                        if (childFolders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              '此層沒有子資料夾',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.black54),
                            ),
                          )
                        else
                          for (final folder in childFolders)
                            ListTile(
                              leading: Icon(
                                Icons.folder_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(folderBaseName(folder)),
                              subtitle: Text(folder.replaceAll('/', '\\')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  setLocalState(() => currentFolder = folder),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton.icon(
              onPressed: () async {
                final name = await promptForFolderName(
                  context,
                  title: '新增資料夾',
                  label: '資料夾名稱',
                );
                if (name == null || name.trim().isEmpty) {
                  return;
                }
                final newFolder = joinFolderPath(
                  currentFolder,
                  limitFolderNameForStorage(name),
                );
                store.createNoteFolder(newFolder);
                setLocalState(() => currentFolder = newFolder);
              },
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('新增資料夾'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, currentFolder),
              child: const Text('移到這裡'),
            ),
          ],
        );
      },
    ),
  );
}
