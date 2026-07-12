part of 'main.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    this.note,
    this.initialFolder = '',
    this.initialTemplateType = NoteTemplateType.general,
    this.readOnly = false,
  });

  final NoteItem? note;
  final String initialFolder;
  final NoteTemplateType initialTemplateType;
  final bool readOnly;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class NoteTemplatePickerPage extends StatelessWidget {
  const NoteTemplatePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: '選擇筆記模板',
          subtitle: '每種模板會用各自的資料格式儲存',
          leading: const PageBackButton(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final type in NoteTemplateType.values) ...[
                NoteTemplatePickerCard(type: type),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NoteTemplatePickerCard extends StatelessWidget {
  const NoteTemplatePickerCard({super.key, required this.type});

  final NoteTemplateType type;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, type),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffe4e8f5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(noteTemplateIcon(type)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noteTemplateLabel(type),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      noteTemplateDescription(type),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController title;
  late final RichNoteTextController body;
  late final TextEditingController tags;
  late String folder;
  late NoteTemplateType templateType;
  late Map<String, dynamic> templateData;
  late final String initialEditorBody;
  late final Map<String, dynamic> initialEditorTemplateData;
  late Map<String, dynamic> noteStyle;
  late List<Map<String, dynamic>> noteImages;
  late List<Map<String, dynamic>> noteAttachments;
  late Map<String, dynamic> noteBackground;
  bool allowPop = false;
  bool didSave = false;
  bool get readOnly => widget.readOnly;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    title = TextEditingController(text: note?.title ?? '');
    tags = TextEditingController(text: formatTagsForEditing(note?.tags ?? []));
    folder = note?.category ?? normalizeFolderPath(widget.initialFolder);
    templateType = note?.templateType ?? widget.initialTemplateType;
    templateData = Map<String, dynamic>.from(
      note?.templateData ?? defaultNoteTemplateData(templateType),
    );
    final richSeed = templateType == NoteTemplateType.general
        ? richNoteSeedFromTemplateData(note?.body ?? '', templateData)
        : RichNoteSeed(text: note?.body ?? '', marks: const []);
    body = RichNoteTextController(text: richSeed.text, marks: richSeed.marks);
    noteStyle = Map<String, dynamic>.from(note?.style ?? defaultNoteStyle());
    noteImages = List<Map<String, dynamic>>.from(
      note?.images ?? <Map<String, dynamic>>[],
    );
    noteAttachments = List<Map<String, dynamic>>.from(
      note?.attachments ?? <Map<String, dynamic>>[],
    );
    noteBackground = Map<String, dynamic>.from(
      note?.background ?? defaultNoteBackground(),
    );
    if (templateType == NoteTemplateType.general) {
      migrateLegacyInlineAssets();
      body.isolateEmbedBlocks(images: noteImages);
      templateData = generalNoteTemplateData(
        templateData,
        body,
        noteImages,
        noteAttachments,
      );
      unawaited(hydrateInlineImageDimensions());
    }
    initialEditorBody = body.text;
    initialEditorTemplateData = cloneJsonMap(templateData);
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    tags.dispose();
    super.dispose();
  }

  bool get hasChanges {
    final note = widget.note;
    final nextTitle = title.text.trim();
    final nextBody = body.text;
    final nextFolder = folder.trim();
    final nextTags = splitTags(tags.text);
    final nextTemplateData = currentNoteTemplateData();
    if (note == null) {
      return (nextTitle.isNotEmpty && nextTitle != '未命名筆記') ||
          nextBody.trim().isNotEmpty ||
          nextFolder.isNotEmpty ||
          nextTags.isNotEmpty ||
          templateType != NoteTemplateType.general ||
          jsonEncode(nextTemplateData) !=
              jsonEncode(defaultNoteTemplateData(templateType)) ||
          jsonEncode(noteStyle) != jsonEncode(defaultNoteStyle()) ||
          noteImages.isNotEmpty ||
          noteAttachments.isNotEmpty ||
          jsonEncode(noteBackground) != jsonEncode(defaultNoteBackground());
    }
    return nextTitle != note.title ||
        nextBody != initialEditorBody ||
        nextFolder != note.category ||
        !stringListsEqual(nextTags, note.tags) ||
        templateType != note.templateType ||
        jsonEncode(nextTemplateData) != jsonEncode(initialEditorTemplateData) ||
        jsonEncode(noteStyle) != jsonEncode(note.style) ||
        jsonEncode(noteImages) != jsonEncode(note.images) ||
        jsonEncode(noteAttachments) != jsonEncode(note.attachments) ||
        jsonEncode(noteBackground) != jsonEncode(note.background);
  }

  Map<String, dynamic> currentNoteTemplateData() {
    if (templateType == NoteTemplateType.general) {
      return generalNoteTemplateData(
        templateData,
        body,
        noteImages,
        noteAttachments,
      );
    }
    return templateData;
  }

  void saveNote() {
    if (readOnly) {
      return;
    }
    if (didSave) {
      return;
    }
    if (!hasChanges) {
      didSave = true;
      return;
    }
    final store = AppStoreScope.of(context);
    final now = DateTime.now();
    final note = widget.note;
    final nextBody = body.text;
    final nextTemplateData = currentNoteTemplateData();
    store.upsertNote(
      NoteItem(
        id: note?.id ?? store.newId('n'),
        title: title.text.trim().isEmpty ? '未命名筆記' : title.text.trim(),
        body: nextBody,
        category: folder.trim(),
        tags: splitTags(tags.text),
        createdAt: note?.createdAt ?? now,
        updatedAt: now,
        isPinned: note?.isPinned ?? false,
        templateType: templateType,
        templateData: nextTemplateData,
        style: noteStyle,
        images: noteImages,
        attachments: noteAttachments,
        background: noteBackground,
      ),
    );
    didSave = true;
  }

  void saveAndExit() {
    if (readOnly) {
      Navigator.pop(context);
      return;
    }
    saveNote();
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void discardAndExit() {
    didSave = true;
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> requestExit() async {
    if (readOnly) {
      Navigator.pop(context);
      return;
    }
    saveAndExit();
  }

  Future<void> deleteAndExit() async {
    final note = widget.note;
    if (note == null) {
      final confirmed = await confirmDelete(
        context,
        title: '刪除筆記？',
        message: '確定要放棄這份尚未儲存的筆記嗎？',
      );
      if (confirmed && mounted) {
        discardAndExit();
      }
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: '刪除筆記？',
      message: '確定要刪除這筆筆記嗎？',
    );
    if (!confirmed || !mounted) {
      return;
    }
    AppStoreScope.of(context).deleteNote(note);
    didSave = true;
    allowPop = true;
    Navigator.pop(context);
  }

  Future<void> createFolder() async {
    final store = AppStoreScope.of(context);
    final name = await promptForText(context, title: '新增資料夾', label: '資料夾名稱');
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final newFolder = joinFolderPath(folder, name);
    store.createNoteFolder(newFolder);
    setState(() => folder = newFolder);
  }

  void setTemplateType(NoteTemplateType value) {
    setState(() {
      templateType = value;
      templateData = defaultNoteTemplateData(value);
    });
  }

  void migrateLegacyInlineAssets() {
    for (final image in noteImages) {
      final id = readString(image['id']);
      if (id.isNotEmpty &&
          !body.hasEmbedBlock(type: richNoteEmbedTypeImage, id: id)) {
        body.appendEmbedBlock(type: richNoteEmbedTypeImage, id: id);
      }
    }
    for (final attachment in noteAttachments) {
      final id = readString(attachment['id']);
      if (id.isNotEmpty &&
          !body.hasEmbedBlock(type: richNoteEmbedTypeAttachment, id: id)) {
        body.appendEmbedBlock(type: richNoteEmbedTypeAttachment, id: id);
      }
    }
  }

  Future<void> hydrateInlineImageDimensions() async {
    var changed = false;
    final nextImages = <Map<String, dynamic>>[];
    for (final image in noteImages) {
      final naturalWidth = readDouble(image['naturalWidth']);
      final naturalHeight = readDouble(image['naturalHeight']);
      if (naturalWidth > 0 && naturalHeight > 0) {
        nextImages.add(image);
        continue;
      }
      final bytes = decodeBase64BytesOrNull(readString(image['bytesBase64']));
      final dimensions = bytes == null
          ? null
          : await decodeImageDimensions(bytes);
      if (dimensions == null) {
        nextImages.add(image);
        continue;
      }
      nextImages.add({
        ...image,
        'naturalWidth': dimensions.width,
        'naturalHeight': dimensions.height,
      });
      changed = true;
    }
    if (changed && mounted) {
      setState(() => noteImages = nextImages);
    }
  }

  void insertBodyToken(String token) {
    final selection = body.selection;
    final text = body.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    body.text = text.replaceRange(start, end, token);
    body.selection = TextSelection.collapsed(offset: start + token.length);
    setState(() {});
  }

  Future<void> addImagePlaceholder() async {
    final file = await NoteFileService.pickImage();
    if (!mounted || file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showToast(context, '無法讀取圖片');
      return;
    }
    final dimensions = await decodeImageDimensions(bytes);
    final naturalWidth = math.max(1.0, dimensions?.width ?? 240.0);
    final naturalHeight = math.max(1.0, dimensions?.height ?? 160.0);
    final initialWidth = math
        .min(280.0, naturalWidth)
        .clamp(80.0, 320.0)
        .toDouble();
    final initialHeight = (initialWidth * naturalHeight / naturalWidth)
        .clamp(60.0, 320.0)
        .toDouble();
    final image = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': file.name,
      'bytesBase64': base64Encode(bytes),
      'size': file.size,
      'alignment': NoteImageAlignment.left.name,
      'x': 0.0,
      'y': 0.0,
      'locked': false,
      'width': initialWidth,
      'height': initialHeight,
      'naturalWidth': naturalWidth,
      'naturalHeight': naturalHeight,
      'crop': '',
      'path': file.path ?? '',
      'row': body.text.split('\n').length,
    };
    final nextImages = [...noteImages, image];
    body.insertEmbedBlock(
      type: richNoteEmbedTypeImage,
      id: readString(image['id']),
    );
    body.isolateEmbedBlocks(images: nextImages);
    setState(() => noteImages = nextImages);
  }

  Future<void> addAttachmentPlaceholder() async {
    final file = await NoteFileService.pickAttachment();
    if (!mounted || file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showToast(context, '無法讀取附件');
      return;
    }
    final attachment = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': file.name,
      'mode': 'file',
      'bytesBase64': base64Encode(bytes),
      'size': file.size,
      'content': '',
      'path': file.path ?? '',
    };
    body.insertEmbedBlock(
      type: richNoteEmbedTypeAttachment,
      id: readString(attachment['id']),
    );
    setState(() => noteAttachments.add(attachment));
  }

  Future<void> editBackground() async {
    var backgroundType = readString(
      noteBackground['type'],
      fallback: readString(noteBackground['imageBytesBase64']).isNotEmpty
          ? 'image'
          : 'color',
    );
    var selectedColor = readString(
      noteBackground['color'],
      fallback: '#FFFFFF',
    );
    var imageName = readString(noteBackground['image']);
    var imageBytesBase64 = readString(noteBackground['imageBytesBase64']);
    var mode = readEnum(
      NoteBackgroundMode.values,
      noteBackground['mode'],
      NoteBackgroundMode.fill,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('背景設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'color',
                    icon: Icon(Icons.palette_outlined),
                    label: Text('顏色'),
                  ),
                  ButtonSegment(
                    value: 'image',
                    icon: Icon(Icons.image_outlined),
                    label: Text('圖片'),
                  ),
                ],
                selected: {backgroundType == 'image' ? 'image' : 'color'},
                onSelectionChanged: (values) =>
                    setModalState(() => backgroundType = values.first),
              ),
              const SizedBox(height: 12),
              if (backgroundType == 'color') ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in const [
                      '#FFFFFF',
                      '#F7F8FC',
                      '#FFF7D6',
                      '#EAF7EF',
                      '#EAF2FF',
                      '#FDECEC',
                      '#202522',
                      '#5967D8',
                      '#8A8F98',
                    ])
                      ChoiceChip(
                        selected:
                            selectedColor.toUpperCase() == color.toUpperCase(),
                        avatar: _ColorSwatch(
                          value: color,
                          selected:
                              selectedColor.toUpperCase() ==
                              color.toUpperCase(),
                        ),
                        label: Text(colorLabel(color)),
                        onSelected: (_) =>
                            setModalState(() => selectedColor = color),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (backgroundType == 'image') ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await NoteFileService.pickImage();
                    if (!mounted || file == null) {
                      return;
                    }
                    final bytes = file.bytes;
                    if (bytes == null || bytes.isEmpty) {
                      showToast(this.context, '無法讀取背景圖片');
                      return;
                    }
                    setModalState(() {
                      backgroundType = 'image';
                      imageName = file.name;
                      imageBytesBase64 = base64Encode(bytes);
                    });
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(imageName.isEmpty ? '選擇圖片' : imageName),
                ),
                const SizedBox(height: 12),
                DropdownMenu<NoteBackgroundMode>(
                  initialSelection: mode,
                  label: const Text('背景模式'),
                  dropdownMenuEntries: NoteBackgroundMode.values
                      .map(
                        (item) => DropdownMenuEntry(
                          value: item,
                          label: noteBackgroundModeLabel(item),
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value != null) {
                      setModalState(() => mode = value);
                    }
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  noteBackground = {
                    'type': backgroundType,
                    'color': selectedColor.trim().isEmpty
                        ? '#FFFFFF'
                        : selectedColor.trim(),
                    'image': imageName.trim(),
                    'imageBytesBase64': imageBytesBase64,
                    'mode': mode.name,
                  };
                });
                Navigator.pop(context);
              },
              child: const Text('套用'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showExportOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: const [
            ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined),
              title: Text('另存為 PDF'),
              subtitle: Text('另存為 PDF'),
            ),
            ListTile(
              leading: Icon(Icons.text_snippet_outlined),
              title: Text('另存為 TXT'),
              subtitle: Text('另存為 txt'),
            ),
            ListTile(
              leading: Icon(Icons.code_outlined),
              title: Text('另存為 Markdown'),
              subtitle: Text('另存為 Markdown'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> insertTodoReference() async {
    final store = AppStoreScope.of(context);
    if (store.todos.isEmpty) {
      showToast(context, '目前沒有可插入的待辦事項');
      return;
    }
    final todo = await showDialog<TodoItem>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('插入待辦事項'),
        children: [
          for (final item in store.todos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                title: Text(item.title),
                subtitle: Text(todoSubtitle(item)),
              ),
            ),
        ],
      ),
    );
    if (todo != null) {
      body.insertEmbedBlock(type: richNoteEmbedTypeTodo, id: todo.id);
    }
  }

  Future<void> insertNoteReference() async {
    final store = AppStoreScope.of(context);
    final notes = store.visibleNotes.where(
      (item) => item.id != widget.note?.id,
    );
    final note = await showDialog<NoteItem>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('插入筆記連結'),
        children: [
          for (final item in notes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(item.title),
            ),
        ],
      ),
    );
    if (note != null) {
      insertBodyToken('[筆記:${note.title}]');
    }
  }

  void handleEditorMenu(NoteEditorMenuAction action) {
    switch (action) {
      case NoteEditorMenuAction.background:
        unawaited(editBackground());
        return;
      case NoteEditorMenuAction.insertNote:
        unawaited(insertNoteReference());
        return;
      case NoteEditorMenuAction.export:
        unawaited(showExportOptions());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: readOnly || allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(requestExit());
      },
      child: Scaffold(
        body: SafeArea(
          child: AppPage(
            title: title.text.trim().isEmpty ? '請輸入標題' : title.text.trim(),
            titleWidget: NoteEditorHeaderFields(
              title: title,
              tags: tags,
              readOnly: readOnly,
              onChanged: () => setState(() {}),
            ),
            leading: PageBackButton(onPressed: requestExit),
            actions: [
              if (!readOnly)
                IconButton(
                  tooltip: '刪除筆記',
                  onPressed: deleteAndExit,
                  icon: const Icon(Icons.delete_outline),
                ),
              PopupMenuButton<NoteEditorMenuAction>(
                tooltip: '更多',
                icon: const Icon(Icons.more_vert),
                onSelected: handleEditorMenu,
                itemBuilder: (context) => [
                  if (!readOnly)
                    const PopupMenuItem(
                      value: NoteEditorMenuAction.background,
                      child: ListTile(
                        leading: Icon(Icons.format_color_fill_outlined),
                        title: Text('背景設定'),
                      ),
                    ),
                  if (!readOnly)
                    const PopupMenuItem(
                      value: NoteEditorMenuAction.insertNote,
                      child: ListTile(
                        leading: Icon(Icons.link),
                        title: Text('插入筆記'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: NoteEditorMenuAction.export,
                    child: ListTile(
                      leading: Icon(Icons.save_alt_outlined),
                      title: Text('另存為'),
                    ),
                  ),
                ],
              ),
            ],
            child: templateType == NoteTemplateType.general
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: GeneralRichTextEditorPanel(
                      controller: body,
                      readOnly: readOnly,
                      style: noteStyle,
                      images: noteImages,
                      attachments: noteAttachments,
                      background: noteBackground,
                      onStyleChanged: (value) =>
                          setState(() => noteStyle = value),
                      onAddImage: addImagePlaceholder,
                      onAddAttachment: addAttachmentPlaceholder,
                      onInsertTodo: insertTodoReference,
                      onImagesChanged: (value) =>
                          setState(() => noteImages = value),
                      onAttachmentsChanged: (value) =>
                          setState(() => noteAttachments = value),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      IgnorePointer(
                        ignoring: readOnly,
                        child: NoteTemplateFields(
                          type: templateType,
                          data: templateData,
                          onChanged: (value) =>
                              setState(() => templateData = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!readOnly) ...[
                        NoteEditorToolbar(
                          style: noteStyle,
                          imageCount: noteImages.length,
                          attachmentCount: noteAttachments.length,
                          onStyleChanged: (value) =>
                              setState(() => noteStyle = value),
                          onAddImage: addImagePlaceholder,
                          onAddAttachment: addAttachmentPlaceholder,
                          onInsertTodo: insertTodoReference,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: body,
                        readOnly: readOnly,
                        minLines: 5,
                        maxLines: 10,
                        style: noteBodyTextStyle(noteStyle, context: context),
                        decoration: InputDecoration(
                          labelText: noteBodyLabel(templateType),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: effectiveNoteBackgroundColor(
                            context,
                            noteBackground,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xffdfe5f4),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xffdfe5f4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      NoteAssetsSummary(
                        images: noteImages,
                        attachments: noteAttachments,
                        background: noteBackground,
                        readOnly: readOnly,
                        onImagesChanged: (value) =>
                            setState(() => noteImages = value),
                        onAttachmentsChanged: (value) =>
                            setState(() => noteAttachments = value),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class NoteTemplateSelector extends StatelessWidget {
  const NoteTemplateSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NoteTemplateType value;
  final ValueChanged<NoteTemplateType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<NoteTemplateType>(
      segments: [
        for (final type in NoteTemplateType.values)
          ButtonSegment(
            value: type,
            icon: Icon(noteTemplateIcon(type)),
            label: Text(noteTemplateLabel(type)),
          ),
      ],
      selected: {value},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}

class NoteTemplateBadge extends StatelessWidget {
  const NoteTemplateBadge({super.key, required this.type});

  final NoteTemplateType type;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Row(
        children: [
          Icon(noteTemplateIcon(type)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noteTemplateLabel(type),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  noteTemplateDescription(type),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoteEditorHeaderFields extends StatelessWidget {
  const NoteEditorHeaderFields({
    super.key,
    required this.title,
    required this.tags,
    required this.readOnly,
    required this.onChanged,
  });

  final TextEditingController title;
  final TextEditingController tags;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: title,
          readOnly: readOnly,
          onChanged: (_) => onChanged(),
          minLines: 1,
          maxLines: 2,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xff171f2f),
          ),
          decoration: const InputDecoration(
            hintText: '請輸入標題',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: tags,
          readOnly: readOnly,
          onChanged: (_) => onChanged(),
          minLines: 1,
          maxLines: 1,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          decoration: const InputDecoration(
            hintText: '#標籤',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

const richTextFormatVersion = 'my_note.rich_text.v1';
const appFlowyMirrorFormatVersion = 'my_note.appflowy.v1';
const richNoteEmbedObject = '\uFFFC';
const richNoteEmbedTypeImage = 'image';
const richNoteEmbedTypeAttachment = 'attachment';
const richNoteEmbedTypeTodo = 'todo';

class RichNoteAttribute {
  const RichNoteAttribute._();

  static const bold = 'bold';
  static const italic = 'italic';
  static const underline = 'underline';
  static const strikethrough = 'strikethrough';
  static const inlineCode = 'inlineCode';
  static const codeBlock = 'codeBlock';
  static const fontSize = 'fontSize';
  static const fontFamily = 'fontFamily';
  static const subscript = 'subscript';
  static const superscript = 'superscript';
  static const heading = 'heading';
  static const quote = 'quote';
  static const embedType = 'embedType';
  static const embedId = 'embedId';
}

class RichNoteMark {
  const RichNoteMark({
    required this.start,
    required this.end,
    required this.attributes,
  });

  final int start;
  final int end;
  final Map<String, dynamic> attributes;

  bool get isValid => end > start && attributes.isNotEmpty;

  RichNoteMark copyWith({
    int? start,
    int? end,
    Map<String, dynamic>? attributes,
  }) {
    return RichNoteMark(
      start: start ?? this.start,
      end: end ?? this.end,
      attributes: attributes ?? Map<String, dynamic>.from(this.attributes),
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'attributes': attributes,
  };

  static RichNoteMark? fromJson(Map<String, dynamic> data, int textLength) {
    final start = readInt(data['start']).clamp(0, textLength).toInt();
    final end = readInt(data['end']).clamp(0, textLength).toInt();
    final attributes = readStringMap(data['attributes']);
    final mark = RichNoteMark(
      start: math.min(start, end),
      end: math.max(start, end),
      attributes: attributes,
    );
    return mark.isValid ? mark : null;
  }
}

class RichNoteEditingSnapshot {
  const RichNoteEditingSnapshot(this.value, this.marks);

  final TextEditingValue value;
  final List<RichNoteMark> marks;
}

class RichNoteTextChange {
  const RichNoteTextChange({
    required this.oldStart,
    required this.oldEnd,
    required this.replacementLength,
    required this.textLength,
  });

  final int oldStart;
  final int oldEnd;
  final int replacementLength;
  final int textLength;

  int get replacementEnd => oldStart + replacementLength;
}

class RichNoteAutoEdit {
  const RichNoteAutoEdit({
    required this.start,
    required this.end,
    required this.replacement,
    required this.cursorOffset,
  });

  final int start;
  final int end;
  final String replacement;
  final int cursorOffset;
}

class RichNoteSeed {
  const RichNoteSeed({required this.text, required this.marks});

  final String text;
  final List<RichNoteMark> marks;
}

class RichNoteTextController extends TextEditingController {
  RichNoteTextController({
    required String text,
    required List<RichNoteMark> marks,
  }) : _marks = normalizeRichNoteMarks(marks, text.length),
       _lastText = text,
       _lastValue = TextEditingValue(
         text: text,
         selection: TextSelection.collapsed(offset: text.length),
       ),
       _lastMarks = normalizeRichNoteMarks(marks, text.length),
       super(text: text) {
    addListener(_handleUserTextChange);
  }

  List<RichNoteMark> _marks;
  String _lastText;
  TextEditingValue _lastValue;
  List<RichNoteMark> _lastMarks;
  final Map<String, Object?> _typingAttributeOverrides = {};
  bool _applyingChange = false;
  final List<RichNoteEditingSnapshot> _undoStack = [];
  final List<RichNoteEditingSnapshot> _redoStack = [];
  TextSelection? _lastValidSelection;
  List<Map<String, dynamic>> _renderImages = const [];
  List<Map<String, dynamic>> _renderAttachments = const [];
  bool _renderReadOnly = false;
  String? _selectedEmbedType;
  String? _selectedEmbedId;
  void Function(String type, String id)? _onEmbedSelected;
  void Function(String type, String id)? _onEmbedBlockTapped;
  ValueChanged<RichImageTapTarget>? _onImageLayoutChanged;
  ValueChanged<Map<String, dynamic>>? _onInlineImageChanged;
  ValueChanged<Map<String, dynamic>>? _onInlineAttachmentChanged;
  void Function(String type, String id)? _onEmbedDeleted;
  double? _renderContentWidth;
  DateTime? _suppressSelectionLogUntil;

  bool get canUndoRichChange => _undoStack.isNotEmpty;
  bool get canRedoRichChange => _redoStack.isNotEmpty;

  List<RichNoteMark> get marks =>
      _marks.map((mark) => mark.copyWith()).toList();

  Map<String, dynamic> toRichTextJson() => {
    'format': richTextFormatVersion,
    'plainText': text,
    'spans': _marks.map((mark) => mark.toJson()).toList(),
  };

  void configureInlineContent({
    required List<Map<String, dynamic>> images,
    required List<Map<String, dynamic>> attachments,
    required bool readOnly,
    required String? selectedType,
    required String? selectedId,
    required void Function(String type, String id) onEmbedSelected,
    required void Function(String type, String id) onEmbedBlockTapped,
    required ValueChanged<RichImageTapTarget> onImageLayoutChanged,
    required ValueChanged<Map<String, dynamic>> onImageChanged,
    required ValueChanged<Map<String, dynamic>> onAttachmentChanged,
    required void Function(String type, String id) onEmbedDeleted,
    double? contentWidth,
  }) {
    _renderImages = images;
    _renderAttachments = attachments;
    _renderReadOnly = readOnly;
    _selectedEmbedType = selectedType;
    _selectedEmbedId = selectedId;
    _onEmbedSelected = onEmbedSelected;
    _onEmbedBlockTapped = onEmbedBlockTapped;
    _onImageLayoutChanged = onImageLayoutChanged;
    _onInlineImageChanged = onImageChanged;
    _onInlineAttachmentChanged = onAttachmentChanged;
    _onEmbedDeleted = onEmbedDeleted;
    _renderContentWidth = contentWidth;
  }

  void insertEmbedBlock({required String type, required String id}) {
    final range = normalizedSelectionRange();
    final currentText = text;
    var replaceStart = range.start;
    var replaceEnd = range.end;
    if (range.isCollapsed && currentText.trim().isEmpty) {
      replaceStart = 0;
      replaceEnd = currentText.length;
    } else {
      while (replaceStart > 1 &&
          currentText[replaceStart - 1] == '\n' &&
          currentText[replaceStart - 2] == '\n') {
        replaceStart--;
      }
      while (replaceEnd + 1 < currentText.length &&
          currentText[replaceEnd] == '\n' &&
          currentText[replaceEnd + 1] == '\n') {
        replaceEnd++;
      }
    }
    final needsLeadingNewLine =
        replaceStart > 0 && currentText[replaceStart - 1] != '\n';
    final needsTrailingNewLine =
        replaceEnd < currentText.length && currentText[replaceEnd] != '\n';
    final leading = needsLeadingNewLine ? '\n' : '';
    final trailing = needsTrailingNewLine || replaceEnd == currentText.length
        ? '\n'
        : '';
    final replacement = '$leading$richNoteEmbedObject$trailing';
    final embedStart = replaceStart + leading.length;
    _pushCurrentUndo();
    _applyingChange = true;
    final nextText = currentText.replaceRange(
      replaceStart,
      replaceEnd,
      replacement,
    );
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: replaceStart,
      oldEnd: replaceEnd,
      replacementLength: replacement.length,
      textLength: nextText.length,
    );
    _marks.add(
      RichNoteMark(
        start: embedStart,
        end: embedStart + 1,
        attributes: {
          RichNoteAttribute.embedType: type,
          RichNoteAttribute.embedId: id,
        },
      ),
    );
    _marks = normalizeRichNoteMarks(_marks, nextText.length);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: (embedStart + 1 + trailing.length)
            .clamp(0, nextText.length)
            .toInt(),
      ),
    );
    _rememberSelection();
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void appendEmbedBlock({required String type, required String id}) {
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    insertEmbedBlock(type: type, id: id);
  }

  bool hasEmbedBlock({required String type, required String id}) {
    return _marks.any(
      (mark) =>
          mark.attributes[RichNoteAttribute.embedType] == type &&
          mark.attributes[RichNoteAttribute.embedId] == id,
    );
  }

  TextRange _embedLineRange(RichNoteMark mark) {
    final currentText = text;
    var start = mark.start.clamp(0, currentText.length).toInt();
    var end = mark.end.clamp(start, currentText.length).toInt();
    while (start > 0 && currentText[start - 1] != '\n') {
      start--;
    }
    while (end < currentText.length && currentText[end] != '\n') {
      end++;
    }
    if (end < currentText.length && currentText[end] == '\n') {
      end++;
    } else if (start > 0 && end == currentText.length) {
      start--;
    }
    return TextRange(start: start, end: end);
  }

  void removeEmbedBlock({required String type, required String id}) {
    final index = _marks.indexWhere(
      (mark) =>
          mark.attributes[RichNoteAttribute.embedType] == type &&
          mark.attributes[RichNoteAttribute.embedId] == id,
    );
    if (index < 0) {
      return;
    }
    final mark = _marks[index];
    final range = _embedLineRange(mark);
    replaceTextRange(range.start, range.end, '');
  }

  bool moveEmbedBlock({
    required String type,
    required String id,
    required int direction,
  }) {
    final index = _marks.indexWhere(
      (mark) =>
          mark.attributes[RichNoteAttribute.embedType] == type &&
          mark.attributes[RichNoteAttribute.embedId] == id,
    );
    if (index < 0 || direction == 0) {
      return false;
    }
    final mark = _marks[index];
    final currentText = text;
    final sourceRange = _embedLineRange(mark);
    var insertAt = sourceRange.start;
    if (direction < 0) {
      if (sourceRange.start <= 0) {
        return false;
      }
      final previousBreak = currentText.lastIndexOf(
        '\n',
        math.max(0, sourceRange.start - 2),
      );
      insertAt = previousBreak + 1;
    } else {
      if (sourceRange.end >= currentText.length) {
        return false;
      }
      final nextBreak = currentText.indexOf('\n', sourceRange.end);
      insertAt = nextBreak < 0 ? currentText.length : nextBreak + 1;
    }
    if (insertAt == sourceRange.start || insertAt == sourceRange.end) {
      return false;
    }
    replaceTextRange(sourceRange.start, sourceRange.end, '');
    final adjustedInsertAt = insertAt > sourceRange.start
        ? insertAt - (sourceRange.end - sourceRange.start)
        : insertAt;
    value = value.copyWith(
      selection: TextSelection.collapsed(
        offset: adjustedInsertAt.clamp(0, text.length).toInt(),
      ),
    );
    insertEmbedBlock(type: type, id: id);
    return true;
  }

  void clearTextSelectionForImageInteraction() {
    suppressSelectionChangeLogForImageInteraction();
    _applyingChange = true;
    final nextValue = value.copyWith(
      selection: const TextSelection.collapsed(offset: -1),
      composing: TextRange.empty,
    );
    value = nextValue;
    _lastValue = nextValue;
    _applyingChange = false;
  }

  void suppressSelectionChangeLogForImageInteraction([
    Duration duration = const Duration(milliseconds: 500),
  ]) {
    _suppressSelectionLogUntil = DateTime.now().add(duration);
  }

  bool get _shouldSuppressSelectionChangeLog {
    final until = _suppressSelectionLogUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _handleUserTextChange() {
    final selectionChanged = value.selection != _lastValue.selection;
    _rememberSelection();
    if (_applyingChange || text == _lastText) {
      if (!_applyingChange && text == _lastText && selectionChanged) {
        if (_shouldSuppressSelectionChangeLog) {
          _lastValue = value;
          return;
        }
        debugPrint(
          'CARET_CHANGED selection=${value.selection.start}-${value.selection.end}',
        );
        _lastValue = value;
      }
      return;
    }
    final previousEmbeds = embedKeysFromRichNoteMarks(_lastMarks);
    final change = richNoteTextChange(oldText: _lastText, newText: text);
    _pushUndo(_lastValue, _lastMarks);
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: change.oldStart,
      oldEnd: change.oldEnd,
      replacementLength: change.replacementLength,
      textLength: change.textLength,
    );
    if (change.replacementLength > 0 && _typingAttributeOverrides.isNotEmpty) {
      final insertedRange = TextRange(
        start: change.oldStart,
        end: change.replacementEnd,
      );
      for (final entry in _typingAttributeOverrides.entries) {
        if (entry.value == false) {
          _marks = removeRichNoteAttribute(
            _marks,
            insertedRange,
            entry.key,
            text.length,
          );
        }
      }
      _applyTypingAttributeOverridesToRange(
        insertedRange,
        textLength: text.length,
      );
    }
    if (text.isEmpty && change.replacementLength == 0) {
      _marks = [];
      _typingAttributeOverrides.clear();
    }
    final prefixDeleteEdit = richListPrefixSpaceDeletionEdit(
      previousText: _lastText,
      currentText: text,
      change: change,
    );
    if (prefixDeleteEdit != null) {
      _applyInternalReplacement(prefixDeleteEdit);
    }
    final autoEdit = prefixDeleteEdit == null
        ? richListContinuationEdit(text, change)
        : null;
    if (autoEdit != null) {
      _applyInternalReplacement(autoEdit);
    }
    _isolateEmbedBlocks();
    _notifyDeletedEmbeds(previousEmbeds);
    _syncLastSnapshot();
  }

  void _notifyDeletedEmbeds(Set<String> previousEmbeds) {
    if (previousEmbeds.isEmpty || _onEmbedDeleted == null) {
      return;
    }
    final currentEmbeds = embedKeysFromRichNoteMarks(_marks);
    for (final key in previousEmbeds.difference(currentEmbeds)) {
      final separator = key.indexOf('\n');
      if (separator <= 0 || separator >= key.length - 1) {
        continue;
      }
      _onEmbedDeleted?.call(
        key.substring(0, separator),
        key.substring(separator + 1),
      );
    }
  }

  void _syncLastSnapshot() {
    _lastText = text;
    _lastValue = value;
    _lastMarks = marks;
    _rememberSelection();
  }

  void _rememberSelection() {
    final currentSelection = selection;
    if (currentSelection.isValid) {
      _lastValidSelection = currentSelection;
    }
  }

  void rememberSelection() {
    _rememberSelection();
  }

  void _pushUndo(
    TextEditingValue value,
    List<RichNoteMark> marks, {
    bool clearRedo = true,
  }) {
    _undoStack.add(
      RichNoteEditingSnapshot(
        value,
        marks.map((mark) => mark.copyWith()).toList(),
      ),
    );
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    if (clearRedo) {
      _redoStack.clear();
    }
  }

  void _pushRedo(TextEditingValue value, List<RichNoteMark> marks) {
    _redoStack.add(
      RichNoteEditingSnapshot(
        value,
        marks.map((mark) => mark.copyWith()).toList(),
      ),
    );
    if (_redoStack.length > 50) {
      _redoStack.removeAt(0);
    }
  }

  void _pushCurrentUndo() {
    _pushUndo(value, marks);
  }

  TextRange normalizedSelectionRange() {
    final currentText = text;
    var selection = this.selection;
    if (!selection.isValid && _lastValidSelection != null) {
      selection = _lastValidSelection!;
    }
    if (!selection.isValid) {
      return TextRange.collapsed(currentText.length);
    }
    final start = math
        .min(selection.start, selection.end)
        .clamp(0, currentText.length)
        .toInt();
    final end = math
        .max(selection.start, selection.end)
        .clamp(0, currentText.length)
        .toInt();
    return TextRange(start: start, end: end);
  }

  TextRange currentLineRange() {
    final range = normalizedSelectionRange();
    final currentText = text;
    final lineStart = range.start <= 0
        ? 0
        : currentText.lastIndexOf('\n', range.start - 1) + 1;
    final rawEnd = range.end >= currentText.length
        ? currentText.length
        : currentText.indexOf('\n', range.end);
    final lineEnd = rawEnd == -1 ? currentText.length : rawEnd;
    return TextRange(start: lineStart, end: lineEnd);
  }

  void replaceSelection(
    String replacement, {
    Map<String, dynamic>? attributes,
  }) {
    final range = normalizedSelectionRange();
    _pushCurrentUndo();
    _applyingChange = true;
    final nextText = text.replaceRange(range.start, range.end, replacement);
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: range.start,
      oldEnd: range.end,
      replacementLength: replacement.length,
      textLength: nextText.length,
    );
    if (attributes != null && attributes.isNotEmpty && replacement.isNotEmpty) {
      _marks.add(
        RichNoteMark(
          start: range.start,
          end: range.start + replacement.length,
          attributes: Map<String, dynamic>.from(attributes),
        ),
      );
    }
    _marks = normalizeRichNoteMarks(_marks, nextText.length);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: range.start + replacement.length,
      ),
    );
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void _applyInternalReplacement(RichNoteAutoEdit edit) {
    _applyingChange = true;
    final nextText = text.replaceRange(edit.start, edit.end, edit.replacement);
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: edit.start,
      oldEnd: edit.end,
      replacementLength: edit.replacement.length,
      textLength: nextText.length,
    );
    _marks = normalizeRichNoteMarks(_marks, nextText.length);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: edit.cursorOffset.clamp(0, nextText.length).toInt(),
      ),
    );
    _applyingChange = false;
  }

  void isolateEmbedBlocks({List<Map<String, dynamic>> images = const []}) {
    _isolateEmbedBlocks(images: images);
    _syncLastSnapshot();
  }

  void _isolateEmbedBlocks({List<Map<String, dynamic>> images = const []}) {
    var guard = 0;
    while (guard < text.length + 8) {
      guard++;
      final currentText = text;
      var applied = false;
      for (var index = 0; index < currentText.length; index++) {
        if (currentText[index] != richNoteEmbedObject) {
          continue;
        }
        if (index > 0 && currentText[index - 1] != '\n') {
          _insertInternalLineBreak(index);
          applied = true;
          break;
        }
        final after = index + 1;
        const requiredNewlines = 1;
        var existingNewlines = 0;
        while (after + existingNewlines < currentText.length &&
            currentText[after + existingNewlines] == '\n') {
          existingNewlines++;
        }
        if (existingNewlines < requiredNewlines) {
          _insertInternalText(
            after + existingNewlines,
            '\n' * (requiredNewlines - existingNewlines),
          );
          applied = true;
          break;
        }
      }
      if (!applied) {
        return;
      }
    }
  }

  void _insertInternalLineBreak(int offset) {
    _insertInternalText(offset, '\n');
  }

  void _insertInternalText(int offset, String replacement) {
    final currentSelection = selection;
    final selectionOffset = currentSelection.isValid
        ? currentSelection.extentOffset
        : text.length;
    final nextCursor =
        selectionOffset + (offset <= selectionOffset ? replacement.length : 0);
    _applyInternalReplacement(
      RichNoteAutoEdit(
        start: offset,
        end: offset,
        replacement: replacement,
        cursorOffset: nextCursor,
      ),
    );
  }

  void applyInlineAttribute(String attribute, Object value) {
    var range = normalizedSelectionRange();
    if (range.isCollapsed) {
      toggleTypingAttribute(attribute, value);
      return;
    }
    _pushCurrentUndo();
    _applyingChange = true;
    if (selectionHasAttribute(attribute, value: value)) {
      _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
    } else {
      _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
      final opposite = oppositeScriptAttribute(attribute);
      if (opposite != null) {
        _marks = removeRichNoteAttribute(_marks, range, opposite, text.length);
      }
      _marks.add(
        RichNoteMark(
          start: range.start,
          end: range.end,
          attributes: {attribute: value},
        ),
      );
      _marks = normalizeRichNoteMarks(_marks, text.length);
    }
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void setInlineAttribute(String attribute, Object value) {
    final range = normalizedSelectionRange();
    if (range.isCollapsed) {
      _typingAttributeOverrides[attribute] = value;
      notifyListeners();
      return;
    }
    _pushCurrentUndo();
    _applyingChange = true;
    _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
    _marks.add(
      RichNoteMark(
        start: range.start,
        end: range.end,
        attributes: {attribute: value},
      ),
    );
    _marks = normalizeRichNoteMarks(_marks, text.length);
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void applyLineAttribute(String attribute, Object value) {
    var range = currentLineRange();
    if (range.isCollapsed) {
      toggleTypingAttribute(attribute, value);
      return;
    }
    _pushCurrentUndo();
    _applyingChange = true;
    if (rangeHasAttribute(range, attribute, value: value)) {
      _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
    } else {
      _marks = removeRichNoteAttribute(_marks, range, attribute, text.length);
      _marks.add(
        RichNoteMark(
          start: range.start,
          end: range.end,
          attributes: {attribute: value},
        ),
      );
      _marks = normalizeRichNoteMarks(_marks, text.length);
    }
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void _applyTypingAttributeOverridesToRange(
    TextRange range, {
    required int textLength,
  }) {
    if (range.isCollapsed || _typingAttributeOverrides.isEmpty) {
      return;
    }
    for (final entry in _typingAttributeOverrides.entries) {
      if (entry.value == false) {
        _marks = removeRichNoteAttribute(_marks, range, entry.key, textLength);
      }
    }
    final enabledAttributes = <String, dynamic>{
      for (final entry in _typingAttributeOverrides.entries)
        if (entry.value != false) entry.key: entry.value,
    };
    if (enabledAttributes.isNotEmpty) {
      _marks.add(
        RichNoteMark(
          start: range.start,
          end: range.end,
          attributes: enabledAttributes,
        ),
      );
    }
    _marks = normalizeRichNoteMarks(_marks, textLength);
  }

  void toggleTypingAttribute(String attribute, Object value) {
    final currentOverride = _typingAttributeOverrides[attribute];
    if (currentOverride == value) {
      if (selectionHasExistingAttribute(attribute, value: value)) {
        _typingAttributeOverrides[attribute] = false;
      } else {
        _typingAttributeOverrides.remove(attribute);
      }
    } else if (currentOverride == false) {
      _typingAttributeOverrides[attribute] = value;
    } else if (selectionHasExistingAttribute(attribute, value: value)) {
      _typingAttributeOverrides[attribute] = false;
    } else {
      _typingAttributeOverrides[attribute] = value;
    }
    final opposite = oppositeScriptAttribute(attribute);
    if (opposite != null && _typingAttributeOverrides[attribute] == value) {
      _typingAttributeOverrides[opposite] = false;
      final range = normalizedSelectionRange();
      if (!range.isCollapsed) {
        _marks = removeRichNoteAttribute(_marks, range, opposite, text.length);
      }
    }
    notifyListeners();
  }

  void updateSelectionFromFlow(TextSelection selection) {
    if (!selection.isValid) {
      return;
    }
    final nextSelection = TextSelection(
      baseOffset: selection.baseOffset.clamp(0, text.length).toInt(),
      extentOffset: selection.extentOffset.clamp(0, text.length).toInt(),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
    final nextValue = value.copyWith(
      selection: nextSelection,
      composing: TextRange.empty,
    );
    _applyingChange = true;
    value = nextValue;
    _lastValue = nextValue;
    _rememberSelection();
    _applyingChange = false;
    notifyListeners();
  }

  void insertTodoCheckbox([String label = '']) {
    final textBefore = text;
    final range = normalizedSelectionRange();
    final needsNewLine = range.start > 0 && textBefore[range.start - 1] != '\n';
    final replacement = '${needsNewLine ? '\n' : ''}☐ ${label.trim()}';
    replaceSelection(replacement);
  }

  bool toggleTodoCheckboxAtOffset(int markerIndex) {
    final currentText = text;
    if (markerIndex < 0 || markerIndex >= currentText.length) {
      return false;
    }
    final marker = currentText[markerIndex];
    if (marker != '☐' && marker != '☑') {
      return false;
    }
    _pushCurrentUndo();
    _applyingChange = true;
    final replacement = marker == '☐' ? '☑' : '☐';
    final nextText = currentText.replaceRange(
      markerIndex,
      markerIndex + 1,
      replacement,
    );
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: markerIndex + 1),
    );
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
    return true;
  }

  bool toggleTodoCheckboxAtSelection() {
    final currentText = text;
    final selection = this.selection;
    if (!selection.isValid || !selection.isCollapsed || currentText.isEmpty) {
      return false;
    }
    final position = selection.extentOffset
        .clamp(0, currentText.length)
        .toInt();
    final lineStart = position <= 0
        ? 0
        : currentText.lastIndexOf('\n', position - 1) + 1;
    final lineEndRaw = currentText.indexOf('\n', lineStart);
    final lineEnd = lineEndRaw == -1 ? currentText.length : lineEndRaw;
    var markerIndex = lineStart;
    while (markerIndex < lineEnd && currentText[markerIndex] == ' ') {
      markerIndex++;
    }
    if (markerIndex >= lineEnd) {
      return false;
    }
    final marker = currentText[markerIndex];
    if (marker != '☐' && marker != '☑') {
      return false;
    }
    final prefixEnd = math.min(markerIndex + 2, lineEnd);
    if (position > prefixEnd) {
      return false;
    }
    return toggleTodoCheckboxAtOffset(markerIndex);
  }

  void prefixSelectedLines(String prefix) {
    final range = normalizedSelectionRange();
    final currentText = text;
    final lineStart = range.start <= 0
        ? 0
        : currentText.lastIndexOf('\n', range.start - 1) + 1;
    final rawEnd = range.end >= currentText.length
        ? currentText.length
        : currentText.indexOf('\n', range.end);
    final lineEnd = rawEnd == -1 ? currentText.length : rawEnd;
    final block = currentText.substring(lineStart, lineEnd);
    final replacement = block
        .split('\n')
        .map((line) => '$prefix$line')
        .join('\n');
    replaceTextRange(lineStart, lineEnd, replacement);
  }

  void replaceTextRange(
    int start,
    int end,
    String replacement, {
    bool applyTypingAttributes = true,
  }) {
    _pushCurrentUndo();
    _applyingChange = true;
    final previousText = text;
    final change = RichNoteTextChange(
      oldStart: start,
      oldEnd: end,
      replacementLength: replacement.length,
      textLength: text.length - (end - start) + replacement.length,
    );
    final nextText = text.replaceRange(start, end, replacement);
    _marks = adjustRichNoteMarksForReplacement(
      _marks,
      oldStart: start,
      oldEnd: end,
      replacementLength: replacement.length,
      textLength: nextText.length,
    );
    if (applyTypingAttributes && replacement.isNotEmpty) {
      _applyTypingAttributeOverridesToRange(
        TextRange(start: start, end: start + replacement.length),
        textLength: nextText.length,
      );
    }
    _marks = normalizeRichNoteMarks(_marks, nextText.length);
    value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    final prefixDeleteEdit = richListPrefixSpaceDeletionEdit(
      previousText: previousText,
      currentText: text,
      change: change,
    );
    if (prefixDeleteEdit != null) {
      _applyInternalReplacement(prefixDeleteEdit);
    }
    final autoEdit = prefixDeleteEdit == null
        ? richListContinuationEdit(text, change)
        : null;
    if (autoEdit != null) {
      _applyInternalReplacement(autoEdit);
    }
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void outdentSelectedLines() {
    final range = normalizedSelectionRange();
    final currentText = text;
    final lineStart = range.start <= 0
        ? 0
        : currentText.lastIndexOf('\n', range.start - 1) + 1;
    final rawEnd = range.end >= currentText.length
        ? currentText.length
        : currentText.indexOf('\n', range.end);
    final lineEnd = rawEnd == -1 ? currentText.length : rawEnd;
    final replacement = currentText
        .substring(lineStart, lineEnd)
        .split('\n')
        .map((line) {
          if (line.startsWith('  ')) return line.substring(2);
          if (line.startsWith('\t')) return line.substring(1);
          return line;
        })
        .join('\n');
    replaceTextRange(lineStart, lineEnd, replacement);
  }

  void applyOrderedList() {
    final range = normalizedSelectionRange();
    final currentText = text;
    final lineStart = range.start <= 0
        ? 0
        : currentText.lastIndexOf('\n', range.start - 1) + 1;
    final rawEnd = range.end >= currentText.length
        ? currentText.length
        : currentText.indexOf('\n', range.end);
    final lineEnd = rawEnd == -1 ? currentText.length : rawEnd;
    final replacement = currentText
        .substring(lineStart, lineEnd)
        .split('\n')
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
    replaceTextRange(lineStart, lineEnd, replacement);
  }

  bool selectionHasAttribute(String attribute, {Object? value}) {
    final range = normalizedSelectionRange();
    if (range.isCollapsed) {
      if (_typingAttributeOverrides.containsKey(attribute)) {
        final override = _typingAttributeOverrides[attribute];
        return override != false && (value == null || override == value);
      }
      return selectionHasExistingAttribute(attribute, value: value);
    }
    return rangeHasAttribute(range, attribute, value: value);
  }

  Object? selectionAttributeValue(String attribute) {
    final range = normalizedSelectionRange();
    if (range.isCollapsed) {
      if (_typingAttributeOverrides.containsKey(attribute)) {
        final override = _typingAttributeOverrides[attribute];
        return override == false ? null : override;
      }
      return attributeValueAtOffset(attribute, range.start);
    }

    Object? sharedValue;
    var hasSharedValue = false;
    var visitedContent = false;
    for (var index = range.start; index < range.end; index++) {
      if (text[index] == '\n') {
        continue;
      }
      visitedContent = true;
      final value = attributeValueAtOffset(attribute, index);
      if (value == null) {
        return null;
      }
      if (!hasSharedValue) {
        sharedValue = value;
        hasSharedValue = true;
      } else if (sharedValue != value) {
        return null;
      }
    }
    return visitedContent && hasSharedValue ? sharedValue : null;
  }

  Object? attributeValueAtOffset(String attribute, int offset) {
    final position = offset.clamp(0, text.length).toInt();
    for (final mark in _marks.reversed) {
      final covers = position == text.length
          ? mark.start < position && mark.end >= position
          : mark.start <= position && mark.end > position;
      if (covers && mark.attributes.containsKey(attribute)) {
        return mark.attributes[attribute];
      }
    }
    return null;
  }

  bool selectionHasExistingAttribute(String attribute, {Object? value}) {
    final range = normalizedSelectionRange();
    if (range.isCollapsed) {
      final position = range.start.clamp(0, text.length).toInt();
      return _marks.any((mark) {
        final covers = position == text.length
            ? mark.start < position && mark.end >= position
            : mark.start <= position && mark.end > position;
        return covers &&
            mark.attributes.containsKey(attribute) &&
            (value == null || mark.attributes[attribute] == value);
      });
    }
    return rangeHasAttribute(range, attribute, value: value);
  }

  bool rangeHasAttribute(TextRange range, String attribute, {Object? value}) {
    for (var index = range.start; index < range.end; index++) {
      if (text[index] == '\n') {
        continue;
      }
      final covered = _marks.any(
        (mark) =>
            mark.start <= index &&
            mark.end > index &&
            mark.attributes.containsKey(attribute) &&
            (value == null || mark.attributes[attribute] == value),
      );
      if (!covered) {
        return false;
      }
    }
    return true;
  }

  void undoRichChange() {
    if (_undoStack.isEmpty) {
      return;
    }
    _applyingChange = true;
    _pushRedo(value, marks);
    final previous = _undoStack.removeLast();
    _marks = previous.marks.map((mark) => mark.copyWith()).toList();
    value = previous.value;
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  void redoRichChange() {
    if (_redoStack.isEmpty) {
      return;
    }
    _applyingChange = true;
    _pushUndo(value, marks, clearRedo: false);
    final next = _redoStack.removeLast();
    _marks = next.marks.map((mark) => mark.copyWith()).toList();
    value = next.value;
    _syncLastSnapshot();
    _applyingChange = false;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final currentText = text;
    if (currentText.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    bool isTodoMarkerAt(int index) {
      if (index < 0 || index >= currentText.length) {
        return false;
      }
      final marker = currentText[index];
      if (marker != '☐' && marker != '☑') {
        return false;
      }
      final lineStart = index <= 0
          ? 0
          : currentText.lastIndexOf('\n', index - 1) + 1;
      for (var i = lineStart; i < index; i++) {
        if (currentText[i] != ' ') {
          return false;
        }
      }
      return true;
    }

    final boundaries = <int>{0, currentText.length};
    for (final mark in _marks) {
      boundaries.add(mark.start.clamp(0, currentText.length).toInt());
      boundaries.add(mark.end.clamp(0, currentText.length).toInt());
    }
    for (var index = 0; index < currentText.length; index++) {
      if (currentText[index] == richNoteEmbedObject || isTodoMarkerAt(index)) {
        boundaries.add(index);
        boundaries.add(index + 1);
      }
    }
    final ordered = boundaries.toList()..sort();
    final children = <InlineSpan>[];
    for (var i = 0; i < ordered.length - 1; i++) {
      final start = ordered[i];
      final end = ordered[i + 1];
      if (end <= start) {
        continue;
      }
      final attributes = <String, dynamic>{};
      for (final mark in _marks) {
        if (mark.start <= start && mark.end >= end) {
          attributes.addAll(mark.attributes);
        }
      }
      if (end == start + 1 && isTodoMarkerAt(start)) {
        final checked = currentText[start] == '☑';
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InlineRichTodoCheckbox(
              checked: checked,
              readOnly: _renderReadOnly,
              onChanged: () => toggleTodoCheckboxAtOffset(start),
            ),
          ),
        );
        continue;
      }
      if (end == start + 1 && currentText[start] == richNoteEmbedObject) {
        final type = readString(attributes[RichNoteAttribute.embedType]);
        final id = readString(attributes[RichNoteAttribute.embedId]);
        final selected = _selectedEmbedType == type && _selectedEmbedId == id;
        if (type == richNoteEmbedTypeImage) {
          final image = firstMapById(_renderImages, id);
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: InlineRichImageBlock(
                image: image,
                selected: selected,
                readOnly: _renderReadOnly,
                moveEnabled: false,
                contentWidth: _renderContentWidth,
                onSelect: () => _onEmbedSelected?.call(type, id),
                onBlockTap: () => _onEmbedBlockTapped?.call(type, id),
                onLayoutChanged: (target) =>
                    _onImageLayoutChanged?.call(target),
                onChanged: (value) => _onInlineImageChanged?.call(value),
              ),
            ),
          );
          continue;
        }
        if (type == richNoteEmbedTypeAttachment) {
          final attachment = firstMapById(_renderAttachments, id);
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InlineRichAttachmentBlock(
                attachment: attachment,
                selected: selected,
                readOnly: _renderReadOnly,
                onSelect: () => _onEmbedSelected?.call(type, id),
                onChanged: (value) => _onInlineAttachmentChanged?.call(value),
              ),
            ),
          );
          continue;
        }
      }
      children.add(
        TextSpan(
          text: currentText.substring(start, end),
          style: richNoteTextStyleForAttributes(context, baseStyle, attributes),
        ),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }
}

List<RichNoteMark> normalizeRichNoteMarks(
  List<RichNoteMark> marks,
  int textLength,
) {
  final normalized = <RichNoteMark>[];
  for (final mark in marks) {
    final start = mark.start.clamp(0, textLength).toInt();
    final end = mark.end.clamp(0, textLength).toInt();
    final next = RichNoteMark(
      start: math.min(start, end),
      end: math.max(start, end),
      attributes: Map<String, dynamic>.from(mark.attributes),
    );
    if (next.isValid) {
      normalized.add(next);
    }
  }
  normalized.sort((a, b) {
    final start = a.start.compareTo(b.start);
    if (start != 0) return start;
    return a.end.compareTo(b.end);
  });
  return normalized;
}

Set<String> embedKeysFromRichNoteMarks(List<RichNoteMark> marks) {
  final keys = <String>{};
  for (final mark in marks) {
    final type = readString(mark.attributes[RichNoteAttribute.embedType]);
    final id = readString(mark.attributes[RichNoteAttribute.embedId]);
    if (type.isNotEmpty && id.isNotEmpty) {
      keys.add('$type\n$id');
    }
  }
  return keys;
}

List<RichNoteMark> adjustRichNoteMarksAfterTextChange(
  List<RichNoteMark> marks, {
  required String oldText,
  required String newText,
}) {
  final change = richNoteTextChange(oldText: oldText, newText: newText);
  return adjustRichNoteMarksForReplacement(
    marks,
    oldStart: change.oldStart,
    oldEnd: change.oldEnd,
    replacementLength: change.replacementLength,
    textLength: change.textLength,
  );
}

RichNoteTextChange richNoteTextChange({
  required String oldText,
  required String newText,
}) {
  var prefix = 0;
  while (prefix < oldText.length &&
      prefix < newText.length &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < oldText.length - prefix &&
      suffix < newText.length - prefix &&
      oldText.codeUnitAt(oldText.length - 1 - suffix) ==
          newText.codeUnitAt(newText.length - 1 - suffix)) {
    suffix++;
  }
  return RichNoteTextChange(
    oldStart: prefix,
    oldEnd: oldText.length - suffix,
    replacementLength: newText.length - prefix - suffix,
    textLength: newText.length,
  );
}

String? oppositeScriptAttribute(String attribute) {
  return switch (attribute) {
    RichNoteAttribute.subscript => RichNoteAttribute.superscript,
    RichNoteAttribute.superscript => RichNoteAttribute.subscript,
    _ => null,
  };
}

RichNoteAutoEdit? richListPrefixSpaceDeletionEdit({
  required String previousText,
  required String currentText,
  required RichNoteTextChange change,
}) {
  if (change.replacementLength != 0 || change.oldEnd - change.oldStart != 1) {
    return null;
  }
  if (change.oldStart < 0 ||
      change.oldEnd > previousText.length ||
      previousText.substring(change.oldStart, change.oldEnd) != ' ') {
    return null;
  }
  final cursor = change.oldStart.clamp(0, currentText.length).toInt();
  final lineStart = cursor <= 0
      ? 0
      : currentText.lastIndexOf('\n', cursor - 1) + 1;
  final beforeCursor = currentText.substring(lineStart, cursor);
  final marker = RegExp(r'^(\s*)(?:\d+\.|•|[☐☑])$').firstMatch(beforeCursor);
  if (marker == null) {
    return null;
  }
  final markerStart = lineStart + (marker.group(1) ?? '').length;
  return RichNoteAutoEdit(
    start: markerStart,
    end: cursor,
    replacement: '',
    cursorOffset: markerStart,
  );
}

RichNoteAutoEdit? richListContinuationEdit(
  String currentText,
  RichNoteTextChange change,
) {
  if (change.replacementLength < 1 ||
      change.replacementEnd > currentText.length) {
    return null;
  }
  final inserted = currentText.substring(
    change.oldStart,
    change.replacementEnd,
  );
  if (!inserted.startsWith('\n')) {
    return null;
  }
  final lineStart = change.oldStart <= 0
      ? 0
      : currentText.lastIndexOf('\n', change.oldStart - 1) + 1;
  final previousLine = currentText.substring(lineStart, change.oldStart);
  final afterInsertedNewLine = change.oldStart + 1;

  final emptyNumbered = RegExp(r'^(\s*)\d+\.\s*$').firstMatch(previousLine);
  if (emptyNumbered != null) {
    return RichNoteAutoEdit(
      start: lineStart,
      end: change.oldStart,
      replacement: '',
      cursorOffset: lineStart + inserted.length,
    );
  }
  final numbered = RegExp(r'^(\s*)(\d+)\.\s+(.+)$').firstMatch(previousLine);
  if (numbered != null) {
    final indent = numbered.group(1) ?? '';
    final nextNumber = (int.tryParse(numbered.group(2) ?? '') ?? 0) + 1;
    final prefix = '$indent$nextNumber. ';
    return RichNoteAutoEdit(
      start: afterInsertedNewLine,
      end: afterInsertedNewLine,
      replacement: prefix,
      cursorOffset: change.replacementEnd + prefix.length,
    );
  }

  final emptyBullet = RegExp(r'^(\s*)•\s*$').firstMatch(previousLine);
  if (emptyBullet != null) {
    return RichNoteAutoEdit(
      start: lineStart,
      end: change.oldStart,
      replacement: '',
      cursorOffset: lineStart + inserted.length,
    );
  }
  final bullet = RegExp(r'^(\s*)•\s+(.+)$').firstMatch(previousLine);
  if (bullet != null) {
    final prefix = '${bullet.group(1) ?? ''}• ';
    return RichNoteAutoEdit(
      start: afterInsertedNewLine,
      end: afterInsertedNewLine,
      replacement: prefix,
      cursorOffset: change.replacementEnd + prefix.length,
    );
  }

  final emptyTodo = RegExp(r'^(\s*)[☐☑]\s*$').firstMatch(previousLine);
  if (emptyTodo != null) {
    return RichNoteAutoEdit(
      start: lineStart,
      end: change.oldStart,
      replacement: '',
      cursorOffset: lineStart + inserted.length,
    );
  }
  final todo = RegExp(r'^(\s*)[☐☑]\s+(.+)$').firstMatch(previousLine);
  if (todo != null) {
    final prefix = '${todo.group(1) ?? ''}☐ ';
    return RichNoteAutoEdit(
      start: afterInsertedNewLine,
      end: afterInsertedNewLine,
      replacement: prefix,
      cursorOffset: change.replacementEnd + prefix.length,
    );
  }

  return null;
}

List<RichNoteMark> adjustRichNoteMarksForReplacement(
  List<RichNoteMark> marks, {
  required int oldStart,
  required int oldEnd,
  required int replacementLength,
  required int textLength,
}) {
  final delta = replacementLength - (oldEnd - oldStart);
  final changedNewEnd = oldStart + replacementLength;
  final next = <RichNoteMark>[];
  for (final mark in marks) {
    if (mark.end <= oldStart) {
      next.add(mark);
    } else if (mark.start >= oldEnd) {
      next.add(mark.copyWith(start: mark.start + delta, end: mark.end + delta));
    } else {
      final start = mark.start <= oldStart ? mark.start : changedNewEnd;
      final end = mark.end >= oldEnd ? mark.end + delta : oldStart;
      if (end > start) {
        next.add(mark.copyWith(start: start, end: end));
      }
    }
  }
  return normalizeRichNoteMarks(next, textLength);
}

List<RichNoteMark> removeRichNoteAttribute(
  List<RichNoteMark> marks,
  TextRange range,
  String attribute,
  int textLength,
) {
  final next = <RichNoteMark>[];
  for (final mark in marks) {
    if (mark.end <= range.start ||
        mark.start >= range.end ||
        !mark.attributes.containsKey(attribute)) {
      next.add(mark);
      continue;
    }
    if (mark.start < range.start) {
      next.add(mark.copyWith(end: range.start));
    }
    final middleAttributes = Map<String, dynamic>.from(mark.attributes)
      ..remove(attribute);
    if (middleAttributes.isNotEmpty) {
      next.add(
        RichNoteMark(
          start: math.max(mark.start, range.start),
          end: math.min(mark.end, range.end),
          attributes: middleAttributes,
        ),
      );
    }
    if (mark.end > range.end) {
      next.add(mark.copyWith(start: range.end));
    }
  }
  return normalizeRichNoteMarks(next, textLength);
}

RichNoteSeed richNoteSeedFromTemplateData(
  String body,
  Map<String, dynamic> templateData,
) {
  final richText = readStringMap(templateData['richText']);
  final storedPlainText = readString(richText['plainText']);
  final plainText = storedPlainText.isEmpty && body.trim().isNotEmpty
      ? body
      : storedPlainText;
  final spans = readMapList(richText['spans'])
      .map((item) => RichNoteMark.fromJson(item, plainText.length))
      .whereType<RichNoteMark>()
      .toList();
  if (spans.isNotEmpty || richText['format'] == richTextFormatVersion) {
    return RichNoteSeed(text: plainText, marks: spans);
  }
  return migrateLegacyRichTextMarkers(body);
}

RichNoteSeed migrateLegacyRichTextMarkers(String body) {
  var text = body;
  final marks = <RichNoteMark>[];

  void removeRange(int start, int length) {
    text = text.replaceRange(start, start + length, '');
    final shifted = adjustRichNoteMarksForReplacement(
      marks,
      oldStart: start,
      oldEnd: start + length,
      replacementLength: 0,
      textLength: text.length,
    );
    marks
      ..clear()
      ..addAll(shifted);
  }

  void consumePair(String open, String close, Map<String, dynamic> attributes) {
    var index = 0;
    while (index < text.length) {
      final start = text.indexOf(open, index);
      if (start < 0) break;
      final contentStart = start + open.length;
      final end = text.indexOf(close, contentStart);
      if (end < 0) break;
      removeRange(end, close.length);
      removeRange(start, open.length);
      final markEnd = end - open.length;
      if (markEnd > start) {
        marks.add(
          RichNoteMark(
            start: start,
            end: markEnd,
            attributes: Map<String, dynamic>.from(attributes),
          ),
        );
      }
      index = math.max(start + 1, markEnd);
    }
  }

  consumePair('```\n', '\n```', {RichNoteAttribute.codeBlock: true});
  consumePair('**', '**', {RichNoteAttribute.bold: true});
  consumePair('~~', '~~', {RichNoteAttribute.strikethrough: true});
  consumePair('<u>', '</u>', {RichNoteAttribute.underline: true});
  consumePair('<sub>', '</sub>', {RichNoteAttribute.subscript: true});
  consumePair('<sup>', '</sup>', {RichNoteAttribute.superscript: true});
  consumePair('`', '`', {RichNoteAttribute.inlineCode: true});

  return RichNoteSeed(
    text: text,
    marks: normalizeRichNoteMarks(marks, text.length),
  );
}

Map<String, dynamic> richTextTemplateData(
  Map<String, dynamic> current,
  RichNoteTextController controller,
) {
  final next = Map<String, dynamic>.from(current);
  next['schema'] = 'general.v2';
  next['richText'] = controller.toRichTextJson();
  return next;
}

Map<String, dynamic> generalNoteTemplateData(
  Map<String, dynamic> current,
  RichNoteTextController controller,
  List<Map<String, dynamic>> images,
  List<Map<String, dynamic>> attachments,
) {
  final next = richTextTemplateData(current, controller);
  next['appflowy'] = appFlowyMirrorJson(
    controller: controller,
    images: images,
    attachments: attachments,
  );
  return next;
}

Map<String, dynamic> blankAppFlowyMirrorJson() {
  return {
    'format': appFlowyMirrorFormatVersion,
    'document': appFlowyDocumentJson([appFlowyParagraphNodeJson('')]),
    'migration': 'blank',
  };
}

Map<String, dynamic> appFlowyMirrorJson({
  required RichNoteTextController controller,
  required List<Map<String, dynamic>> images,
  required List<Map<String, dynamic>> attachments,
}) {
  final nodes = <Map<String, dynamic>>[];
  final text = controller.text;
  final marks = controller.marks;
  final buffer = StringBuffer();

  void flushParagraph({bool force = false}) {
    if (!force && buffer.isEmpty) {
      return;
    }
    nodes.add(appFlowyParagraphNodeJson(buffer.toString()));
    buffer.clear();
  }

  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    if (character == richNoteEmbedObject) {
      flushParagraph();
      final mark = firstRichNoteMarkAtOffset(marks, index);
      final type = readString(mark?.attributes[RichNoteAttribute.embedType]);
      final id = readString(mark?.attributes[RichNoteAttribute.embedId]);
      if (type == richNoteEmbedTypeImage) {
        final image = nullableMapById(images, id);
        if (image != null) {
          nodes.add(appFlowyImageNodeFromNoteImage(image));
        }
      } else if (type == richNoteEmbedTypeAttachment) {
        final attachment = nullableMapById(attachments, id);
        if (attachment != null) {
          nodes.add(
            afe.paragraphNode(
              text: '附件：${readString(attachment['name'], fallback: '未命名附件')}',
            ),
          );
        }
      }
      continue;
    }
    if (character == '\n') {
      flushParagraph(force: true);
      continue;
    }
    buffer.write(character);
  }
  flushParagraph(force: nodes.isEmpty);
  return {
    'format': appFlowyMirrorFormatVersion,
    'document': appFlowyDocumentJson(nodes),
    'imageBlockCount': images.length,
    'attachmentParagraphCount': attachments.length,
    'migration': 'richTextMirror',
  };
}

Map<String, dynamic> appFlowyDocumentJson(List<Map<String, dynamic>> nodes) {
  return {
    'document': {'type': 'page', if (nodes.isNotEmpty) 'children': nodes},
  };
}

Map<String, dynamic> appFlowyParagraphNodeJson(String text) {
  return {
    'type': 'paragraph',
    'data': {
      'delta': [
        {'insert': text},
      ],
    },
  };
}

final afe = _AppFlowyJsonCompat();

class _AppFlowyJsonCompat {
  Map<String, dynamic> paragraphNode({String? text}) =>
      appFlowyParagraphNodeJson(text ?? '');
}

RichNoteMark? firstRichNoteMarkAtOffset(List<RichNoteMark> marks, int offset) {
  for (final mark in marks) {
    if (mark.start <= offset && mark.end > offset) {
      return mark;
    }
  }
  return null;
}

Map<String, dynamic> appFlowyImageNodeFromNoteImage(
  Map<String, dynamic> image,
) {
  final bytesBase64 = readString(image['bytesBase64']);
  final name = readString(image['name'], fallback: 'image');
  final url = bytesBase64.isNotEmpty
      ? 'data:image/*;base64,$bytesBase64'
      : readString(image['path'], fallback: name);
  final alignment = readEnum(
    NoteImageAlignment.values,
    image['alignment'],
    NoteImageAlignment.left,
  );
  final align = switch (alignment) {
    NoteImageAlignment.center => 'center',
    NoteImageAlignment.right => 'right',
    _ => 'left',
  };
  return {
    'type': 'image',
    'data': {
      'url': url,
      'align': align,
      'width': readDouble(image['width'], fallback: 240),
      'height': readDouble(image['height'], fallback: 160),
    },
  };
}

TextStyle richNoteTextStyleForAttributes(
  BuildContext context,
  TextStyle base,
  Map<String, dynamic> attributes,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final inlineFontFamily = readString(attributes[RichNoteAttribute.fontFamily]);
  final inlineFontSize = readDouble(attributes[RichNoteAttribute.fontSize]);
  final decorations = <TextDecoration>[];
  if (attributes[RichNoteAttribute.underline] == true) {
    decorations.add(TextDecoration.underline);
  }
  if (attributes[RichNoteAttribute.strikethrough] == true) {
    decorations.add(TextDecoration.lineThrough);
  }
  var style = base.copyWith(
    fontFamily: inlineFontFamily.isEmpty
        ? base.fontFamily
        : inlineFontFamily == 'System'
        ? null
        : inlineFontFamily,
    fontSize: inlineFontSize > 0 ? inlineFontSize : base.fontSize,
    fontWeight: attributes[RichNoteAttribute.bold] == true
        ? FontWeight.w800
        : base.fontWeight,
    fontStyle:
        attributes[RichNoteAttribute.italic] == true ||
            attributes[RichNoteAttribute.quote] == true
        ? FontStyle.italic
        : base.fontStyle,
    decoration: decorations.isEmpty
        ? base.decoration
        : TextDecoration.combine(decorations),
  );
  if (attributes[RichNoteAttribute.inlineCode] == true ||
      attributes[RichNoteAttribute.codeBlock] == true) {
    style = style.copyWith(
      fontFamily: 'monospace',
      color: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest,
    );
  }
  if (attributes[RichNoteAttribute.subscript] == true) {
    style = style.copyWith(
      fontSize: (style.fontSize ?? 16) * 0.62,
      fontWeight: FontWeight.w800,
      color: colorScheme.primary,
      fontFeatures: const [FontFeature.subscripts()],
    );
  }
  if (attributes[RichNoteAttribute.superscript] == true) {
    style = style.copyWith(
      fontSize: (style.fontSize ?? 16) * 0.62,
      fontWeight: FontWeight.w800,
      color: colorScheme.primary,
      fontFeatures: const [FontFeature.superscripts()],
    );
  }
  final heading = readInt(attributes[RichNoteAttribute.heading]);
  if (heading > 0) {
    final multiplier = switch (heading) {
      1 => 1.55,
      2 => 1.32,
      _ => 1.16,
    };
    style = style.copyWith(
      fontSize: (style.fontSize ?? 16) * multiplier,
      fontWeight: FontWeight.w900,
      height: 1.2,
    );
  }
  if (attributes[RichNoteAttribute.quote] == true) {
    style = style.copyWith(color: colorScheme.onSurfaceVariant);
  }
  return style;
}

class RichImageTapTarget {
  const RichImageTapTarget({
    required this.id,
    required this.blockGlobalRect,
    required this.visualGlobalRect,
    required this.visualLocalRect,
    required this.imageBlockHeight,
  });

  final String id;
  final Rect blockGlobalRect;
  final Rect visualGlobalRect;
  final Rect visualLocalRect;
  final double imageBlockHeight;

  bool containsVisualPoint(Offset globalPosition) =>
      visualGlobalRect.contains(globalPosition);

  bool containsBlockPoint(Offset globalPosition) =>
      blockGlobalRect.contains(globalPosition);

  String visualTapDebugLog() {
    return 'IMAGE_VISUAL_TAP id=$id '
        'imageBlock.y=${visualLocalRect.top.toStringAsFixed(1)} '
        'imageBlock.height=${imageBlockHeight.toStringAsFixed(1)} '
        'imageVisualRect=${visualLocalRect.left.toStringAsFixed(1)},'
        '${visualLocalRect.top.toStringAsFixed(1)},'
        '${visualLocalRect.width.toStringAsFixed(1)},'
        '${visualLocalRect.height.toStringAsFixed(1)} '
        'nextParagraph.y>=${imageBlockHeight.toStringAsFixed(1)}';
  }

  String blockTapDebugLog() {
    return 'IMAGE_BLOCK_BACKGROUND_TAP id=$id '
        'imageBlock.height=${imageBlockHeight.toStringAsFixed(1)}';
  }
}

enum RichNoteFlowBlockType { text, image, attachment, todo }

class RichNoteFlowBlock {
  const RichNoteFlowBlock({
    required this.type,
    required this.order,
    required this.start,
    required this.end,
    this.text = '',
    this.id = '',
  });

  final RichNoteFlowBlockType type;
  final int order;
  final int start;
  final int end;
  final String text;
  final String id;
}

class RichNoteFlowTextController extends TextEditingController {
  RichNoteFlowTextController({
    required String text,
    required this.parent,
    required this.rangeStart,
    required this.readOnly,
  }) : super(text: text);

  RichNoteTextController parent;
  int rangeStart;
  bool readOnly;

  void updateRichSource({
    required RichNoteTextController parent,
    required int rangeStart,
    required bool readOnly,
  }) {
    this.parent = parent;
    this.rangeStart = rangeStart;
    this.readOnly = readOnly;
  }

  void notifyRichSourceChanged() {
    notifyListeners();
  }

  bool _isTodoMarkerAt(int index) {
    if (index < 0 || index >= text.length) {
      return false;
    }
    final marker = text[index];
    if (marker != '☐' && marker != '☑') {
      return false;
    }
    final lineStart = index == 0 || text[index - 1] == '\n';
    final followedBySpace = index + 1 < text.length && text[index + 1] == ' ';
    return lineStart && followedBySpace;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final currentText = text;
    if (currentText.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }
    final boundaries = <int>{0, currentText.length};
    for (final mark in parent.marks) {
      if (mark.attributes.containsKey(RichNoteAttribute.embedType)) {
        continue;
      }
      final localStart = (mark.start - rangeStart).clamp(0, currentText.length);
      final localEnd = (mark.end - rangeStart).clamp(0, currentText.length);
      if (localEnd > localStart) {
        boundaries.add(localStart.toInt());
        boundaries.add(localEnd.toInt());
      }
    }
    for (var index = 0; index < currentText.length; index++) {
      if (_isTodoMarkerAt(index)) {
        boundaries
          ..add(index)
          ..add(index + 1);
      }
    }
    final ordered = boundaries.toList()..sort();
    final children = <InlineSpan>[];
    for (var index = 0; index < ordered.length - 1; index++) {
      final start = ordered[index];
      final end = ordered[index + 1];
      if (end <= start) {
        continue;
      }
      if (end == start + 1 && _isTodoMarkerAt(start)) {
        final checked = currentText[start] == '☑';
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InlineRichTodoCheckbox(
              checked: checked,
              readOnly: readOnly,
              onChanged: () =>
                  parent.toggleTodoCheckboxAtOffset(rangeStart + start),
            ),
          ),
        );
        continue;
      }
      final attributes = <String, dynamic>{};
      final globalStart = rangeStart + start;
      final globalEnd = rangeStart + end;
      for (final mark in parent.marks) {
        if (mark.attributes.containsKey(RichNoteAttribute.embedType)) {
          continue;
        }
        if (mark.start < globalEnd && mark.end > globalStart) {
          attributes.addAll(mark.attributes);
        }
      }
      children.add(
        TextSpan(
          text: currentText.substring(start, end),
          style: richNoteTextStyleForAttributes(context, baseStyle, attributes),
        ),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }
}

List<RichNoteFlowBlock> richNoteFlowBlocks(RichNoteTextController controller) {
  final text = controller.text;
  final marks = controller.marks;
  final blocks = <RichNoteFlowBlock>[];
  var order = 0;
  var textStart = 0;

  void addTextBlock(int start, int end, {bool force = false}) {
    final safeStart = start.clamp(0, text.length).toInt();
    final safeEnd = end.clamp(safeStart, text.length).toInt();
    if (!force && safeEnd <= safeStart && blocks.isNotEmpty) {
      return;
    }
    blocks.add(
      RichNoteFlowBlock(
        type: RichNoteFlowBlockType.text,
        order: order++,
        start: safeStart,
        end: safeEnd,
        text: text.substring(safeStart, safeEnd),
      ),
    );
  }

  for (var index = 0; index < text.length; index++) {
    if (text[index] != richNoteEmbedObject) {
      continue;
    }
    final textEnd = index > textStart && text[index - 1] == '\n'
        ? index - 1
        : index;
    addTextBlock(textStart, textEnd);

    final mark = firstRichNoteMarkAtOffset(marks, index);
    final type = readString(mark?.attributes[RichNoteAttribute.embedType]);
    final id = readString(mark?.attributes[RichNoteAttribute.embedId]);
    if (type == richNoteEmbedTypeImage) {
      blocks.add(
        RichNoteFlowBlock(
          type: RichNoteFlowBlockType.image,
          order: order++,
          start: index,
          end: index + 1,
          id: id,
        ),
      );
    } else if (type == richNoteEmbedTypeAttachment) {
      blocks.add(
        RichNoteFlowBlock(
          type: RichNoteFlowBlockType.attachment,
          order: order++,
          start: index,
          end: index + 1,
          id: id,
        ),
      );
    } else if (type == richNoteEmbedTypeTodo) {
      blocks.add(
        RichNoteFlowBlock(
          type: RichNoteFlowBlockType.todo,
          order: order++,
          start: index,
          end: index + 1,
          id: id,
        ),
      );
    }

    textStart = index + 1;
    if (textStart < text.length && text[textStart] == '\n') {
      textStart++;
    }
  }

  final needsTrailingText =
      blocks.isEmpty || blocks.last.type != RichNoteFlowBlockType.text;
  addTextBlock(
    textStart,
    text.length,
    force: needsTrailingText && textStart >= text.length,
  );
  if (blocks.isEmpty) {
    addTextBlock(0, 0, force: true);
  }
  return blocks;
}

class GeneralRichTextEditorPanel extends StatefulWidget {
  const GeneralRichTextEditorPanel({
    super.key,
    required this.controller,
    required this.readOnly,
    required this.style,
    required this.images,
    required this.attachments,
    required this.background,
    required this.onStyleChanged,
    required this.onAddImage,
    required this.onAddAttachment,
    required this.onInsertTodo,
    required this.onImagesChanged,
    required this.onAttachmentsChanged,
  });

  final RichNoteTextController controller;
  final bool readOnly;
  final Map<String, dynamic> style;
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic> background;
  final ValueChanged<Map<String, dynamic>> onStyleChanged;
  final VoidCallback onAddImage;
  final VoidCallback onAddAttachment;
  final VoidCallback onInsertTodo;
  final ValueChanged<List<Map<String, dynamic>>> onImagesChanged;
  final ValueChanged<List<Map<String, dynamic>>> onAttachmentsChanged;

  @override
  State<GeneralRichTextEditorPanel> createState() =>
      _GeneralRichTextEditorPanelState();
}

class _GeneralRichTextEditorPanelState
    extends State<GeneralRichTextEditorPanel> {
  String? selectedEmbedType;
  String? selectedEmbedId;
  final FocusNode bodyFocusNode = FocusNode(debugLabel: 'rich-note-body');
  final Map<int, TextEditingController> flowTextControllers = {};
  final Map<int, FocusNode> flowTextFocusNodes = {};
  final Map<int, TextRange> flowTextRanges = {};
  final Map<int, GlobalKey> flowTextKeys = {};
  final Map<String, RichImageTapTarget> imageTapTargets = {};
  Timer? restoreBodyFocusTimer;
  Timer? clearSuppressedParagraphTapTimer;
  bool suppressNextParagraphTap = false;
  bool imageMoveEnabled = false;
  bool updatingFlowTextController = false;
  bool refreshingFlowFormatting = false;
  int? lastActiveFlowTextOrder;
  late String richControllerContentSignature;
  DateTime? lastImageMoveRequestAt;

  Map<String, dynamic>? get selectedImage =>
      selectedEmbedType == richNoteEmbedTypeImage
      ? nullableMapById(widget.images, selectedEmbedId ?? '')
      : null;

  Map<String, dynamic>? get selectedAttachment =>
      selectedEmbedType == richNoteEmbedTypeAttachment
      ? nullableMapById(widget.attachments, selectedEmbedId ?? '')
      : null;

  TodoItem? get selectedTodoReference {
    if (selectedEmbedType != richNoteEmbedTypeTodo || selectedEmbedId == null) {
      return null;
    }
    final store = AppStoreScope.of(context);
    for (final item in store.todos) {
      if (item.id == selectedEmbedId) {
        return item;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    richControllerContentSignature = richControllerSignature(widget.controller);
    widget.controller.addListener(handleRichControllerChanged);
  }

  @override
  void didUpdateWidget(covariant GeneralRichTextEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(handleRichControllerChanged);
      richControllerContentSignature = richControllerSignature(
        widget.controller,
      );
      widget.controller.addListener(handleRichControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(handleRichControllerChanged);
    restoreBodyFocusTimer?.cancel();
    clearSuppressedParagraphTapTimer?.cancel();
    for (final controller in flowTextControllers.values) {
      controller.dispose();
    }
    for (final focusNode in flowTextFocusNodes.values) {
      focusNode.dispose();
    }
    bodyFocusNode.dispose();
    super.dispose();
  }

  String richControllerSignature(RichNoteTextController controller) {
    return jsonEncode({
      'text': controller.text,
      'marks': controller.marks.map((mark) => mark.toJson()).toList(),
    });
  }

  void handleRichControllerChanged() {
    final nextSignature = richControllerSignature(widget.controller);
    final contentChanged = nextSignature != richControllerContentSignature;
    if (contentChanged) {
      richControllerContentSignature = nextSignature;
    }
    if (!mounted) {
      return;
    }
    if (contentChanged) {
      refreshingFlowFormatting = true;
      for (final controller in flowTextControllers.values) {
        if (controller is RichNoteFlowTextController) {
          controller.notifyRichSourceChanged();
        }
      }
      refreshingFlowFormatting = false;
    }
    setState(() {});
  }

  void selectEmbed(String type, String id) {
    if (widget.readOnly) {
      return;
    }
    if (type == richNoteEmbedTypeImage) {
      FocusManager.instance.primaryFocus?.unfocus();
      widget.controller.clearTextSelectionForImageInteraction();
    }
    final isSameSelection = selectedEmbedType == type && selectedEmbedId == id;
    setState(() {
      selectedEmbedType = type;
      selectedEmbedId = id;
      if (!isSameSelection || type != richNoteEmbedTypeImage) {
        imageMoveEnabled = false;
      }
    });
  }

  void blockEmbedBackgroundTap(String type, String id) {
    if (type == richNoteEmbedTypeImage) {
      FocusManager.instance.primaryFocus?.unfocus();
      widget.controller.clearTextSelectionForImageInteraction();
      clearEmbedSelection();
      focusNearestTextBlockToEmbed(type, id);
    }
  }

  void focusNearestTextBlockToEmbed(String type, String id) {
    if (widget.readOnly) {
      return;
    }
    final targetType = type == richNoteEmbedTypeImage
        ? RichNoteFlowBlockType.image
        : RichNoteFlowBlockType.attachment;
    final blocks = richNoteFlowBlocks(widget.controller);
    final embedIndex = blocks.indexWhere(
      (block) => block.type == targetType && block.id == id,
    );
    if (embedIndex < 0) {
      return;
    }

    RichNoteFlowBlock? targetBlock;
    for (var index = embedIndex + 1; index < blocks.length; index++) {
      if (blocks[index].type == RichNoteFlowBlockType.text) {
        targetBlock = blocks[index];
        break;
      }
    }
    if (targetBlock == null) {
      for (var index = embedIndex - 1; index >= 0; index--) {
        if (blocks[index].type == RichNoteFlowBlockType.text) {
          targetBlock = blocks[index];
          break;
        }
      }
    }
    final block = targetBlock;
    if (block == null) {
      return;
    }
    final controller = flowTextControllerFor(block);
    final focusNode = flowTextFocusNodeFor(block);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final offset = controller.text.length;
      controller.selection = TextSelection.collapsed(offset: offset);
      focusNode.requestFocus();
      syncFlowSelection(block);
      final focusContext = focusNode.context;
      if (focusContext != null) {
        Scrollable.ensureVisible(
          focusContext,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void registerImageTapTarget(RichImageTapTarget target) {
    imageTapTargets[target.id] = target;
  }

  void removeStaleImageTapTargets() {
    final activeIds = widget.images
        .map((image) => readString(image['id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    imageTapTargets.removeWhere((id, _) => !activeIds.contains(id));
  }

  RichImageTapTarget? imageTapTargetAt(Offset globalPosition) {
    final targets = imageTapTargets.values.toList(growable: false).reversed;
    for (final target in targets) {
      if (target.containsVisualPoint(globalPosition)) {
        return target;
      }
    }
    for (final target in targets) {
      if (target.containsBlockPoint(globalPosition)) {
        return target;
      }
    }
    return null;
  }

  void temporarilyDisableBodyFocus() {
    bodyFocusNode.canRequestFocus = false;
    restoreBodyFocusTimer?.cancel();
    restoreBodyFocusTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        bodyFocusNode.canRequestFocus = true;
      }
    });
  }

  void suppressUpcomingParagraphTap() {
    suppressNextParagraphTap = true;
    clearSuppressedParagraphTapTimer?.cancel();
    clearSuppressedParagraphTapTimer = Timer(
      const Duration(milliseconds: 350),
      () {
        if (mounted) {
          suppressNextParagraphTap = false;
        }
      },
    );
  }

  void handleBodyPointerDown(PointerDownEvent event) {
    if (widget.readOnly) {
      return;
    }
    final target = imageTapTargetAt(event.position);
    if (target == null) {
      return;
    }
    suppressUpcomingParagraphTap();
    temporarilyDisableBodyFocus();
    widget.controller.suppressSelectionChangeLogForImageInteraction();
    if (target.containsVisualPoint(event.position)) {
      debugPrint(target.visualTapDebugLog());
      selectEmbed(richNoteEmbedTypeImage, target.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          selectEmbed(richNoteEmbedTypeImage, target.id);
        }
      });
    } else {
      debugPrint(target.blockTapDebugLog());
      blockEmbedBackgroundTap(richNoteEmbedTypeImage, target.id);
    }
  }

  void clearEmbedSelection() {
    if (selectedEmbedType != null || selectedEmbedId != null) {
      setState(() {
        selectedEmbedType = null;
        selectedEmbedId = null;
        imageMoveEnabled = false;
      });
    }
  }

  void updateImage(Map<String, dynamic> image) {
    final id = readString(image['id']);
    final next = widget.images
        .map((item) => readString(item['id']) == id ? image : item)
        .toList(growable: false);
    widget.controller.isolateEmbedBlocks(images: next);
    widget.onImagesChanged(next);
  }

  void requestImageBlockMove(String id, int direction) {
    final now = DateTime.now();
    final last = lastImageMoveRequestAt;
    if (last != null && now.difference(last).inMilliseconds < 80) {
      return;
    }
    lastImageMoveRequestAt = now;
    final moved = widget.controller.moveEmbedBlock(
      type: richNoteEmbedTypeImage,
      id: id,
      direction: direction,
    );
    if (!moved) {
      return;
    }
    final image = nullableMapById(widget.images, id);
    if (image != null) {
      updateImage({...image, 'y': 0.0});
    } else {
      setState(() {});
    }
  }

  void updateAttachment(Map<String, dynamic> attachment) {
    final id = readString(attachment['id']);
    final next = widget.attachments
        .map((item) => readString(item['id']) == id ? attachment : item)
        .toList(growable: false);
    widget.onAttachmentsChanged(next);
  }

  void deleteSelectedImage() {
    final image = selectedImage;
    if (image == null) {
      return;
    }
    final id = readString(image['id']);
    widget.controller.removeEmbedBlock(type: richNoteEmbedTypeImage, id: id);
    widget.onImagesChanged(
      widget.images.where((item) => readString(item['id']) != id).toList(),
    );
    clearEmbedSelection();
  }

  void deleteSelectedAttachment() {
    final attachment = selectedAttachment;
    if (attachment == null) {
      return;
    }
    final id = readString(attachment['id']);
    widget.controller.removeEmbedBlock(
      type: richNoteEmbedTypeAttachment,
      id: id,
    );
    widget.onAttachmentsChanged(
      widget.attachments.where((item) => readString(item['id']) != id).toList(),
    );
    clearEmbedSelection();
  }

  void removeKeyboardDeletedEmbed(String type, String id) {
    if (type == richNoteEmbedTypeImage) {
      widget.onImagesChanged(
        widget.images.where((item) => readString(item['id']) != id).toList(),
      );
    } else if (type == richNoteEmbedTypeAttachment) {
      widget.onAttachmentsChanged(
        widget.attachments
            .where((item) => readString(item['id']) != id)
            .toList(),
      );
    }
    if (selectedEmbedType == type && selectedEmbedId == id) {
      clearEmbedSelection();
    }
  }

  void setSelectedTodoReferenceDone(bool done) {
    final todo = selectedTodoReference;
    if (todo == null || todo.done == done) {
      return;
    }
    AppStoreScope.of(context).toggleTodo(todo);
    setState(() {});
  }

  void removeSelectedTodoReference() {
    final id = selectedEmbedId;
    if (selectedEmbedType != richNoteEmbedTypeTodo || id == null) {
      return;
    }
    widget.controller.removeEmbedBlock(type: richNoteEmbedTypeTodo, id: id);
    clearEmbedSelection();
  }

  TextEditingController flowTextControllerFor(RichNoteFlowBlock block) {
    final controller = flowTextControllers.putIfAbsent(block.order, () {
      final nextController = RichNoteFlowTextController(
        text: block.text,
        parent: widget.controller,
        rangeStart: block.start,
        readOnly: widget.readOnly,
      );
      nextController.addListener(
        () => handleFlowTextControllerChanged(block.order),
      );
      return nextController;
    });
    if (controller is RichNoteFlowTextController) {
      controller.updateRichSource(
        parent: widget.controller,
        rangeStart: block.start,
        readOnly: widget.readOnly,
      );
    }
    if (controller.text != block.text) {
      final selectionOffset = controller.selection.extentOffset
          .clamp(0, block.text.length)
          .toInt();
      updatingFlowTextController = true;
      controller.value = TextEditingValue(
        text: block.text,
        selection: TextSelection.collapsed(offset: selectionOffset),
      );
      updatingFlowTextController = false;
    }
    flowTextRanges[block.order] = TextRange(start: block.start, end: block.end);
    return controller;
  }

  FocusNode flowTextFocusNodeFor(RichNoteFlowBlock block) {
    return flowTextFocusNodes.putIfAbsent(
      block.order,
      () => FocusNode(debugLabel: 'rich-note-flow-${block.order}'),
    );
  }

  GlobalKey flowTextKeyFor(RichNoteFlowBlock block) {
    return flowTextKeys.putIfAbsent(
      block.order,
      () => GlobalKey(debugLabel: 'rich-note-flow-key-${block.order}'),
    );
  }

  Rect? flowTextRectForOrder(int order) {
    final context = flowTextKeys[order]?.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void focusFlowTextBlock(
    RichNoteFlowBlock block, {
    bool atStart = false,
    bool ensureVisible = true,
  }) {
    if (widget.readOnly) {
      return;
    }
    final controller = flowTextControllerFor(block);
    final focusNode = flowTextFocusNodeFor(block);
    lastActiveFlowTextOrder = block.order;
    final offset = atStart ? 0 : controller.text.length;
    controller.selection = TextSelection.collapsed(offset: offset);
    focusNode.requestFocus();
    syncFlowSelection(block);
    if (!ensureVisible) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final focusContext =
          flowTextKeys[block.order]?.currentContext ?? focusNode.context;
      if (focusContext != null) {
        Scrollable.ensureVisible(
          focusContext,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void focusNearestTextBlockAt(Offset globalPosition) {
    if (widget.readOnly) {
      return;
    }
    final blocks = richNoteFlowBlocks(widget.controller)
        .where((block) => block.type == RichNoteFlowBlockType.text)
        .toList(growable: false);
    if (blocks.isEmpty) {
      return;
    }

    RichNoteFlowBlock? nearestBlock;
    Rect? nearestRect;
    var nearestDistance = double.infinity;
    for (final block in blocks) {
      final rect = flowTextRectForOrder(block.order);
      if (rect == null) {
        continue;
      }
      if (rect.contains(globalPosition)) {
        return;
      }
      final verticalDistance = globalPosition.dy < rect.top
          ? rect.top - globalPosition.dy
          : globalPosition.dy > rect.bottom
          ? globalPosition.dy - rect.bottom
          : 0.0;
      final horizontalDistance = globalPosition.dx < rect.left
          ? rect.left - globalPosition.dx
          : globalPosition.dx > rect.right
          ? globalPosition.dx - rect.right
          : 0.0;
      final distance = verticalDistance + horizontalDistance * 0.15;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestBlock = block;
        nearestRect = rect;
      }
    }

    final targetBlock = nearestBlock ?? blocks.last;
    final rect = nearestRect;
    final atStart = rect != null && globalPosition.dy < rect.center.dy;
    clearEmbedSelection();
    focusFlowTextBlock(targetBlock, atStart: atStart);
  }

  void handleFlowTextControllerChanged(int order) {
    if (updatingFlowTextController || refreshingFlowFormatting) {
      return;
    }
    final controller = flowTextControllers[order];
    final range = flowTextRanges[order];
    if (controller == null || range == null || !controller.selection.isValid) {
      return;
    }
    final focusNode = flowTextFocusNodes[order];
    if (focusNode != null && !focusNode.hasFocus) {
      return;
    }
    lastActiveFlowTextOrder = order;
    syncFlowSelectionByOrder(order);
  }

  void replaceFlowTextBlock(RichNoteFlowBlock block, String nextText) {
    final range =
        flowTextRanges[block.order] ??
        TextRange(start: block.start, end: block.end);
    final currentText = widget.controller.text;
    final safeStart = range.start.clamp(0, currentText.length).toInt();
    final safeEnd = range.end.clamp(safeStart, currentText.length).toInt();
    final previousText = currentText.substring(safeStart, safeEnd);
    final change = richNoteTextChange(oldText: previousText, newText: nextText);
    final replacement = nextText.substring(
      change.oldStart,
      change.replacementEnd,
    );
    widget.controller.replaceTextRange(
      safeStart + change.oldStart,
      safeStart + change.oldEnd,
      replacement,
    );
    refreshFlowTextBlockFromParent(block.order);
    setState(() {});
  }

  void refreshFlowTextBlockFromParent(int preferredOrder) {
    final parentSelection = widget.controller.selection;
    final blocks = richNoteFlowBlocks(widget.controller);
    RichNoteFlowBlock? targetBlock;
    for (final block in blocks) {
      if (block.type == RichNoteFlowBlockType.text &&
          block.order == preferredOrder) {
        targetBlock = block;
        break;
      }
    }
    if (targetBlock == null ||
        parentSelection.extentOffset < targetBlock.start ||
        parentSelection.extentOffset > targetBlock.end) {
      for (final block in blocks) {
        if (block.type != RichNoteFlowBlockType.text) {
          continue;
        }
        if (parentSelection.extentOffset >= block.start &&
            parentSelection.extentOffset <= block.end) {
          targetBlock = block;
          break;
        }
      }
    }
    if (targetBlock == null) {
      return;
    }
    final targetController = flowTextControllerFor(targetBlock);
    flowTextFocusNodeFor(targetBlock);
    flowTextRanges[targetBlock.order] = TextRange(
      start: targetBlock.start,
      end: targetBlock.end,
    );
    updatingFlowTextController = true;
    final localBase = parentSelection.baseOffset - targetBlock.start;
    final localExtent = parentSelection.extentOffset - targetBlock.start;
    targetController.value = TextEditingValue(
      text: targetBlock.text,
      selection: TextSelection(
        baseOffset: localBase.clamp(0, targetBlock.text.length).toInt(),
        extentOffset: localExtent.clamp(0, targetBlock.text.length).toInt(),
        affinity: parentSelection.affinity,
        isDirectional: parentSelection.isDirectional,
      ),
    );
    updatingFlowTextController = false;
    lastActiveFlowTextOrder = targetBlock.order;
  }

  void syncFlowSelection(RichNoteFlowBlock block) {
    syncFlowSelectionByOrder(block.order);
  }

  void syncFlowSelectionByOrder(int order) {
    final controller = flowTextControllers[order];
    if (controller == null || !controller.selection.isValid) {
      return;
    }
    final range = flowTextRanges[order];
    if (range == null) {
      return;
    }
    lastActiveFlowTextOrder = order;
    final textLength = widget.controller.text.length;
    final baseOffset = (range.start + controller.selection.baseOffset)
        .clamp(0, textLength)
        .toInt();
    final extentOffset = (range.start + controller.selection.extentOffset)
        .clamp(0, textLength)
        .toInt();
    widget.controller.updateSelectionFromFlow(
      TextSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
        affinity: controller.selection.affinity,
        isDirectional: controller.selection.isDirectional,
      ),
    );
  }

  bool flowSelectionIsInBlock(RichNoteFlowBlock block) {
    final selection = widget.controller.selection;
    if (!selection.isValid) {
      return false;
    }
    return selection.extentOffset >= block.start &&
        selection.extentOffset <= block.end;
  }

  double flowCaretFontSizeForBlock(
    RichNoteFlowBlock block,
    TextStyle bodyStyle,
  ) {
    final baseSize = bodyStyle.fontSize ?? 16;
    if (!flowSelectionIsInBlock(block)) {
      return baseSize;
    }
    final selectedSize = readDouble(
      widget.controller.selectionAttributeValue(RichNoteAttribute.fontSize),
    );
    return selectedSize > 0 ? selectedSize : baseSize;
  }

  String? flowCaretFontFamilyForBlock(
    RichNoteFlowBlock block,
    TextStyle bodyStyle,
  ) {
    if (!flowSelectionIsInBlock(block)) {
      return bodyStyle.fontFamily;
    }
    final selectedFamily = readString(
      widget.controller.selectionAttributeValue(RichNoteAttribute.fontFamily),
    );
    if (selectedFamily.isEmpty) {
      return bodyStyle.fontFamily;
    }
    return selectedFamily == 'System' ? null : selectedFamily;
  }

  double flowMaxFontSizeForBlock(RichNoteFlowBlock block, TextStyle bodyStyle) {
    var maxSize = math.max(
      bodyStyle.fontSize ?? 16,
      flowCaretFontSizeForBlock(block, bodyStyle),
    );
    for (final mark in widget.controller.marks) {
      if (mark.attributes.containsKey(RichNoteAttribute.embedType) ||
          mark.end <= block.start ||
          mark.start >= block.end) {
        continue;
      }
      final size = readDouble(mark.attributes[RichNoteAttribute.fontSize]);
      if (size > maxSize) {
        maxSize = size;
      }
    }
    return maxSize;
  }

  bool flowBlockOnlyHasInputPrefix(RichNoteFlowBlock block) {
    final trimmed = block.text.trim();
    return block.text.isEmpty ||
        RegExp(r'^(?:\d+\.|•|[☐☑])$').hasMatch(trimmed);
  }

  TextStyle flowTextFieldStyleForBlock(
    RichNoteFlowBlock block,
    TextStyle bodyStyle,
  ) {
    if (!flowBlockOnlyHasInputPrefix(block)) {
      return bodyStyle;
    }
    return bodyStyle.copyWith(
      fontFamily: flowCaretFontFamilyForBlock(block, bodyStyle),
      fontSize: flowCaretFontSizeForBlock(block, bodyStyle),
    );
  }

  StrutStyle flowStrutStyleForBlock(
    RichNoteFlowBlock block,
    TextStyle bodyStyle,
  ) {
    return StrutStyle(
      fontFamily: flowCaretFontFamilyForBlock(block, bodyStyle),
      fontSize: flowMaxFontSizeForBlock(block, bodyStyle),
      height: bodyStyle.height,
      forceStrutHeight: false,
    );
  }

  int? focusedFlowTextOrder() {
    for (final entry in flowTextFocusNodes.entries) {
      if (entry.value.hasFocus) {
        lastActiveFlowTextOrder = entry.key;
        return entry.key;
      }
    }
    final lastOrder = lastActiveFlowTextOrder;
    return lastOrder != null && flowTextControllers.containsKey(lastOrder)
        ? lastOrder
        : null;
  }

  void runToolbarActionPreservingEditorFocus(VoidCallback action) {
    final focusedOrder = focusedFlowTextOrder();
    if (focusedOrder != null) {
      syncFlowSelectionByOrder(focusedOrder);
    }
    action();
    if (focusedOrder == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final parentSelection = widget.controller.selection;
      final blocks = richNoteFlowBlocks(widget.controller);
      final targetBlock =
          blocks.cast<RichNoteFlowBlock?>().firstWhere(
            (block) =>
                block?.type == RichNoteFlowBlockType.text &&
                block?.order == focusedOrder,
            orElse: () => null,
          ) ??
          blocks.cast<RichNoteFlowBlock?>().firstWhere(
            (block) =>
                block?.type == RichNoteFlowBlockType.text &&
                parentSelection.extentOffset >= block!.start &&
                parentSelection.extentOffset <= block.end,
            orElse: () => null,
          );
      final targetOrder = targetBlock?.order ?? focusedOrder;
      final controller = flowTextControllers[targetOrder];
      final focusNode = flowTextFocusNodes[targetOrder];
      if (controller == null || focusNode == null) {
        return;
      }
      if (targetBlock != null) {
        flowTextRanges[targetOrder] = TextRange(
          start: targetBlock.start,
          end: targetBlock.end,
        );
        updatingFlowTextController = true;
        controller.value = TextEditingValue(
          text: targetBlock.text,
          selection: TextSelection(
            baseOffset: (parentSelection.baseOffset - targetBlock.start)
                .clamp(0, targetBlock.text.length)
                .toInt(),
            extentOffset: (parentSelection.extentOffset - targetBlock.start)
                .clamp(0, targetBlock.text.length)
                .toInt(),
            affinity: parentSelection.affinity,
            isDirectional: parentSelection.isDirectional,
          ),
        );
        updatingFlowTextController = false;
      }
      focusNode.requestFocus();
      syncFlowSelectionByOrder(targetOrder);
    });
  }

  Future<void> cropSelectedImage() async {
    final image = selectedImage;
    if (image == null) {
      return;
    }
    final sourcePath = readString(image['path']);
    if (sourcePath.isEmpty) {
      showToast(context, '目前平台無法取得圖片路徑，請重新插入圖片後再裁切');
      return;
    }
    final cropped = await NoteFileService.cropImage(context, sourcePath);
    if (!mounted || cropped == null) {
      return;
    }
    final bytes = await cropped.readAsBytes();
    updateImage({
      ...image,
      'bytesBase64': base64Encode(bytes),
      'size': bytes.length,
      'path': cropped.path,
    });
  }

  Future<void> openSelectedAttachment() async {
    final attachment = selectedAttachment;
    if (attachment == null) {
      return;
    }
    final name = readString(attachment['name'], fallback: '附件');
    final bytes = decodeBase64BytesOrNull(
      readString(attachment['bytesBase64']),
    );
    final preview = bytes == null ? null : safeUtf8Preview(bytes);
    final isImage = bytes != null && isImageFileName(name);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: isImage
                ? Image.memory(bytes, fit: BoxFit.contain)
                : preview == null || preview.trim().isEmpty
                ? const Text('此附件無法在筆記內預覽，可下載後使用裝置上的其他 App 開啟。')
                : SelectableText(preview),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('關閉'),
          ),
          TextButton.icon(
            onPressed: bytes == null || bytes.isEmpty
                ? null
                : () {
                    Navigator.pop(dialogContext);
                    unawaited(downloadSelectedAttachment());
                  },
            icon: const Icon(Icons.download_outlined),
            label: const Text('下載'),
          ),
        ],
      ),
    );
  }

  Future<void> downloadSelectedAttachment() async {
    final attachment = selectedAttachment;
    if (attachment == null) {
      return;
    }
    final bytes = decodeBase64BytesOrNull(
      readString(attachment['bytesBase64']),
    );
    if (bytes == null || bytes.isEmpty) {
      showToast(context, '附件內容無法下載');
      return;
    }
    final savedPath = await NoteFileService.saveBytes(
      fileName: readString(attachment['name'], fallback: 'attachment'),
      bytes: bytes,
    );
    if (!mounted) {
      return;
    }
    showToast(context, savedPath == null ? '已取消下載' : '附件已儲存');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = effectiveNoteBackgroundColor(
      context,
      widget.background,
    );
    final backgroundImage = effectiveNoteBackgroundImage(widget.background);
    removeStaleImageTapTargets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.readOnly) ...[
          if (selectedImage != null)
            ModernRichImageEditToolbar(
              image: selectedImage!,
              moveEnabled: imageMoveEnabled,
              onImageChanged: updateImage,
              onMoveEnabledChanged: (value) =>
                  setState(() => imageMoveEnabled = value),
              onCrop: cropSelectedImage,
              onDelete: deleteSelectedImage,
              onDone: clearEmbedSelection,
            )
          else if (selectedAttachment != null)
            RichAttachmentEditToolbar(
              attachment: selectedAttachment!,
              onOpen: openSelectedAttachment,
              onDownload: downloadSelectedAttachment,
              onDelete: deleteSelectedAttachment,
              onDone: clearEmbedSelection,
            )
          else if (selectedTodoReference != null)
            RichTodoReferenceEditToolbar(
              todo: selectedTodoReference!,
              onMarkDone: () => setSelectedTodoReferenceDone(true),
              onMarkUndone: () => setSelectedTodoReferenceDone(false),
              onRemove: removeSelectedTodoReference,
            )
          else
            RichTextTemplateToolbar(
              controller: widget.controller,
              style: widget.style,
              runEditorAction: runToolbarActionPreservingEditorFocus,
              onStyleChanged: widget.onStyleChanged,
              onAddImage: widget.onAddImage,
              onAddAttachment: widget.onAddAttachment,
              onInsertTodo: widget.onInsertTodo,
            ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: Material(
            color: backgroundImage == null
                ? backgroundColor
                : Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                image: backgroundImage,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final contentWidth = constraints.maxWidth.isFinite
                              ? constraints.maxWidth
                              : null;
                          widget.controller.configureInlineContent(
                            images: widget.images,
                            attachments: widget.attachments,
                            readOnly: widget.readOnly,
                            selectedType: selectedEmbedType,
                            selectedId: selectedEmbedId,
                            onEmbedSelected: selectEmbed,
                            onEmbedBlockTapped: blockEmbedBackgroundTap,
                            onImageLayoutChanged: registerImageTapTarget,
                            onImageChanged: updateImage,
                            onAttachmentChanged: updateAttachment,
                            onEmbedDeleted: removeKeyboardDeletedEmbed,
                            contentWidth: contentWidth,
                          );
                          final blocks = richNoteFlowBlocks(widget.controller);
                          final bodyStyle = noteBodyTextStyle(
                            widget.style,
                            context: context,
                          );
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: widget.readOnly
                                ? null
                                : (details) => focusNearestTextBlockAt(
                                    details.globalPosition,
                                  ),
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final block in blocks)
                                      switch (block.type) {
                                        RichNoteFlowBlockType.text => Builder(
                                          builder: (context) {
                                            final controller =
                                                flowTextControllerFor(block);
                                            final focusNode =
                                                flowTextFocusNodeFor(block);
                                            final shouldCollapseEmptyBlock =
                                                blocks.length > 1 &&
                                                block.text.isEmpty &&
                                                !focusNode.hasFocus &&
                                                block.end <
                                                    widget
                                                        .controller
                                                        .text
                                                        .length;
                                            if (shouldCollapseEmptyBlock) {
                                              return KeyedSubtree(
                                                key: flowTextKeyFor(block),
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onTap: widget.readOnly
                                                      ? null
                                                      : () =>
                                                            focusFlowTextBlock(
                                                              block,
                                                            ),
                                                  child: const SizedBox(
                                                    height: 8,
                                                  ),
                                                ),
                                              );
                                            }
                                            final textFieldStyle =
                                                flowTextFieldStyleForBlock(
                                                  block,
                                                  bodyStyle,
                                                );
                                            final cursorHeight =
                                                flowCaretFontSizeForBlock(
                                                  block,
                                                  bodyStyle,
                                                ) *
                                                (bodyStyle.height ?? 1.25);
                                            return KeyedSubtree(
                                              key: flowTextKeyFor(block),
                                              child: TextField(
                                                controller: controller,
                                                focusNode: focusNode,
                                                readOnly: widget.readOnly,
                                                cursorHeight: cursorHeight,
                                                strutStyle:
                                                    flowStrutStyleForBlock(
                                                      block,
                                                      bodyStyle,
                                                    ),
                                                maxLines: null,
                                                minLines:
                                                    blocks.length == 1 &&
                                                        block.text.isEmpty
                                                    ? 10
                                                    : 1,
                                                style: textFieldStyle,
                                                onChanged: widget.readOnly
                                                    ? null
                                                    : (value) =>
                                                          replaceFlowTextBlock(
                                                            block,
                                                            value,
                                                          ),
                                                onTap: widget.readOnly
                                                    ? null
                                                    : () {
                                                        debugPrint(
                                                          'PARAGRAPH_TAP',
                                                        );
                                                        clearEmbedSelection();
                                                        syncFlowSelection(
                                                          block,
                                                        );
                                                      },
                                                decoration: InputDecoration(
                                                  hintText:
                                                      widget.controller.text
                                                          .trim()
                                                          .isEmpty
                                                      ? '開始輸入筆記內容'
                                                      : null,
                                                  border: InputBorder.none,
                                                  enabledBorder:
                                                      InputBorder.none,
                                                  focusedBorder:
                                                      InputBorder.none,
                                                  filled: false,
                                                  isCollapsed: true,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        RichNoteFlowBlockType.image =>
                                          InlineRichImageBlock(
                                            image: firstMapById(
                                              widget.images,
                                              block.id,
                                            ),
                                            selected:
                                                selectedEmbedType ==
                                                    richNoteEmbedTypeImage &&
                                                selectedEmbedId == block.id,
                                            readOnly: widget.readOnly,
                                            moveEnabled: imageMoveEnabled,
                                            contentWidth: contentWidth,
                                            onSelect: () => selectEmbed(
                                              richNoteEmbedTypeImage,
                                              block.id,
                                            ),
                                            onBlockTap: () =>
                                                blockEmbedBackgroundTap(
                                                  richNoteEmbedTypeImage,
                                                  block.id,
                                                ),
                                            onLayoutChanged:
                                                registerImageTapTarget,
                                            onChanged: updateImage,
                                            onMoveRequest: (direction) =>
                                                requestImageBlockMove(
                                                  block.id,
                                                  direction,
                                                ),
                                          ),
                                        RichNoteFlowBlockType.attachment =>
                                          InlineRichAttachmentBlock(
                                            attachment: firstMapById(
                                              widget.attachments,
                                              block.id,
                                            ),
                                            selected:
                                                selectedEmbedType ==
                                                    richNoteEmbedTypeAttachment &&
                                                selectedEmbedId == block.id,
                                            readOnly: widget.readOnly,
                                            onSelect: () => selectEmbed(
                                              richNoteEmbedTypeAttachment,
                                              block.id,
                                            ),
                                            onChanged: updateAttachment,
                                          ),
                                        RichNoteFlowBlockType.todo =>
                                          InlineRichTodoReferenceBlock(
                                            todoId: block.id,
                                            readOnly: widget.readOnly,
                                            selected:
                                                selectedEmbedType ==
                                                    richNoteEmbedTypeTodo &&
                                                selectedEmbedId == block.id,
                                            onSelect: () => selectEmbed(
                                              richNoteEmbedTypeTodo,
                                              block.id,
                                            ),
                                          ),
                                      },
                                    const SizedBox(height: 96),
                                  ],
                                ),
                              ),
                            ),
                          );
                          /*
                        return Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: handleBodyPointerDown,
                          child: TextField(
                            controller: widget.controller,
                            focusNode: bodyFocusNode,
                            readOnly: widget.readOnly,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            style: noteBodyTextStyle(
                              widget.style,
                              context: context,
                            ),
                            onTap: widget.readOnly
                                ? null
                                : () {
                                    if (suppressNextParagraphTap) {
                                      suppressNextParagraphTap = false;
                                      return;
                                    }
                                    debugPrint('PARAGRAPH_TAP');
                                    widget.controller.rememberSelection();
                                    clearEmbedSelection();
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          widget.controller.rememberSelection();
                                          widget.controller
                                              .toggleTodoCheckboxAtSelection();
                                        });
                                  },
                            decoration: const InputDecoration(
                              hintText: '開始輸入筆記內容',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isCollapsed: true,
                            ),
                          ),
                        );
                        */
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NoteInlineAssetsStrip extends StatelessWidget {
  const NoteInlineAssetsStrip({
    super.key,
    required this.images,
    required this.attachments,
    required this.readOnly,
    required this.onImagesChanged,
    required this.onAttachmentsChanged,
  });

  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> attachments;
  final bool readOnly;
  final ValueChanged<List<Map<String, dynamic>>> onImagesChanged;
  final ValueChanged<List<Map<String, dynamic>>> onAttachmentsChanged;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty && attachments.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final image in images)
              NoteInlineImageTile(
                image: image,
                readOnly: readOnly,
                onDelete: () {
                  final next = List<Map<String, dynamic>>.from(images)
                    ..remove(image);
                  onImagesChanged(next);
                },
              ),
            for (final attachment in attachments)
              NoteInlineAttachmentTile(
                attachment: attachment,
                readOnly: readOnly,
                onDelete: () {
                  final next = List<Map<String, dynamic>>.from(attachments)
                    ..remove(attachment);
                  onAttachmentsChanged(next);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class NoteInlineImageTile extends StatelessWidget {
  const NoteInlineImageTile({
    super.key,
    required this.image,
    required this.readOnly,
    required this.onDelete,
  });

  final Map<String, dynamic> image;
  final bool readOnly;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bytesText = readString(image['bytesBase64']);
    final bytes = decodeBase64BytesOrNull(bytesText);
    return SizedBox(
      width: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: bytes == null
                        ? const Center(child: Icon(Icons.broken_image_outlined))
                        : Image.memory(bytes, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      readString(image['name'], fallback: '圖片'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              if (!readOnly)
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    tooltip: '移除圖片',
                    onPressed: onDelete,
                    icon: const Icon(Icons.close, size: 18),
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteInlineAttachmentTile extends StatelessWidget {
  const NoteInlineAttachmentTile({
    super.key,
    required this.attachment,
    required this.readOnly,
    required this.onDelete,
  });

  final Map<String, dynamic> attachment;
  final bool readOnly;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final size = readInt(attachment['size']);
    return InputChip(
      avatar: const Icon(Icons.attach_file, size: 18),
      label: Text(
        '${readString(attachment['name'], fallback: '附件')}'
        '${size > 0 ? ' · ${formatFileSize(size)}' : ''}',
      ),
      onDeleted: readOnly ? null : onDelete,
    );
  }
}

class InlineRichTodoCheckbox extends StatelessWidget {
  const InlineRichTodoCheckbox({
    super.key,
    required this.checked,
    required this.readOnly,
    required this.onChanged,
  });

  final bool checked;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 26,
      child: Checkbox(
        value: checked,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: readOnly ? null : (_) => onChanged(),
      ),
    );
  }
}

class InlineRichTodoReferenceBlock extends StatelessWidget {
  const InlineRichTodoReferenceBlock({
    super.key,
    required this.todoId,
    required this.readOnly,
    required this.selected,
    required this.onSelect,
  });

  final String todoId;
  final bool readOnly;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    TodoItem? todo;
    for (final item in store.todos) {
      if (item.id == todoId) {
        todo = item;
        break;
      }
    }
    final colorScheme = Theme.of(context).colorScheme;
    if (todo == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.checklist_rtl),
                SizedBox(width: 10),
                Expanded(child: Text('待辦事項已不存在')),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: readOnly ? null : onSelect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: todo.done
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: todo.done,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: readOnly
                      ? null
                      : (_) {
                          onSelect();
                          AppStoreScope.of(context).toggleTodo(todo!);
                        },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        todo.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration: todo.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        todo.done
                            ? todoCompletedLabel(todo)
                            : todoSubtitle(todo),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.link, size: 16, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RichTodoReferenceEditToolbar extends StatelessWidget {
  const RichTodoReferenceEditToolbar({
    super.key,
    required this.todo,
    required this.onMarkDone,
    required this.onMarkUndone,
    required this.onRemove,
  });

  final TodoItem todo;
  final VoidCallback onMarkDone;
  final VoidCallback onMarkUndone;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _RichAssetToolbarShell(
      children: [
        RichToolbarIconButton(
          tooltip: '完成',
          icon: Icons.check,
          active: todo.done,
          onPressed: onMarkDone,
        ),
        RichToolbarIconButton(
          tooltip: '未完成',
          icon: Icons.close,
          active: !todo.done,
          onPressed: onMarkUndone,
        ),
        RichToolbarIconButton(
          tooltip: '自本筆記移除',
          icon: Icons.delete_outline,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class InlineRichImageBlock extends StatelessWidget {
  const InlineRichImageBlock({
    super.key,
    required this.image,
    required this.selected,
    required this.readOnly,
    required this.moveEnabled,
    required this.contentWidth,
    required this.onSelect,
    required this.onBlockTap,
    required this.onLayoutChanged,
    required this.onChanged,
    this.onMoveRequest,
  });

  final Map<String, dynamic> image;
  final bool selected;
  final bool readOnly;
  final bool moveEnabled;
  final double? contentWidth;
  final VoidCallback onSelect;
  final VoidCallback onBlockTap;
  final ValueChanged<RichImageTapTarget> onLayoutChanged;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final ValueChanged<int>? onMoveRequest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = decodeBase64BytesOrNull(readString(image['bytesBase64']));
    final locked = image['locked'] == true;
    final alignment = readEnum(
      NoteImageAlignment.values,
      image['alignment'],
      NoteImageAlignment.left,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = math
            .max(
              160.0,
              contentWidth ??
                  (constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 680.0),
            )
            .toDouble();
        final maxImageWidth = math.max(80.0, blockWidth);
        final width = readDouble(
          image['width'],
          fallback: 240,
        ).clamp(80.0, maxImageWidth).toDouble();
        final height = readDouble(
          image['height'],
          fallback: 160,
        ).clamp(60.0, 900.0).toDouble();
        final visualWidth = width;
        final visualHeight = height;
        final borderWidth = readDouble(image['borderWidth']);
        final borderColor = colorFromHex(
          readString(image['borderColor'], fallback: '#5967D8'),
        );
        const blockVerticalPadding = 0.0;
        const handlePadding = 0.0;
        final fixedLeft = switch (alignment) {
          NoteImageAlignment.center => (blockWidth - visualWidth) / 2,
          NoteImageAlignment.right => blockWidth - visualWidth,
          _ => 0.0,
        };
        final freeLeft = readDouble(image['x'], fallback: fixedLeft);
        final imageLeft =
            (alignment == NoteImageAlignment.free ? freeLeft : fixedLeft)
                .clamp(0.0, math.max(0, blockWidth - visualWidth))
                .toDouble();
        const imageOffsetY = 0.0;
        final imageTop = blockVerticalPadding + handlePadding + imageOffsetY;
        final imageBlockHeight =
            imageTop + visualHeight + blockVerticalPadding + handlePadding;
        final clampingHeight = math.max(
          imageBlockHeight + 320.0,
          visualHeight + blockVerticalPadding + (handlePadding * 2) + 120.0,
        );
        final imageRect = Rect.fromLTWH(
          imageLeft.toDouble(),
          imageTop,
          visualWidth,
          visualHeight,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final renderObject = context.findRenderObject();
          if (renderObject is! RenderBox ||
              !renderObject.attached ||
              !renderObject.hasSize) {
            return;
          }
          final blockTopLeft = renderObject.localToGlobal(Offset.zero);
          onLayoutChanged(
            RichImageTapTarget(
              id: readString(image['id']),
              blockGlobalRect:
                  blockTopLeft & Size(blockWidth, imageBlockHeight),
              visualGlobalRect: imageRect.shift(blockTopLeft),
              visualLocalRect: imageRect,
              imageBlockHeight: imageBlockHeight,
            ),
          );
        });

        void handleImageVisualTap() {
          final blockBottom = imageBlockHeight;
          debugPrint(
            'IMAGE_VISUAL_TAP id=${readString(image['id'])} '
            'imageBlock.y=${imageTop.toStringAsFixed(1)} '
            'imageBlock.height=${imageBlockHeight.toStringAsFixed(1)} '
            'imageVisualRect=${imageRect.left.toStringAsFixed(1)},'
            '${imageRect.top.toStringAsFixed(1)},'
            '${imageRect.width.toStringAsFixed(1)},'
            '${imageRect.height.toStringAsFixed(1)} '
            'nextParagraph.y>=${blockBottom.toStringAsFixed(1)}',
          );
          onSelect();
        }

        void handleImageBlockBackgroundTap() {
          debugPrint(
            'IMAGE_BLOCK_BACKGROUND_TAP id=${readString(image['id'])} '
            'imageBlock.height=${imageBlockHeight.toStringAsFixed(1)}',
          );
          onBlockTap();
        }

        void applyTransformRect(Rect rect) {
          final nextWidth = rect.width.clamp(80.0, maxImageWidth).toDouble();
          final nextHeight = rect.height.clamp(60.0, 900.0).toDouble();
          final nextX = rect.left
              .clamp(0.0, math.max(0.0, blockWidth - nextWidth))
              .toDouble();
          onChanged({
            ...image,
            'alignment': NoteImageAlignment.free.name,
            'x': nextX,
            'y': 0.0,
            'width': nextWidth,
            'height': nextHeight,
          });
        }

        Widget buildImageBox(Size size) {
          return MouseRegion(
            cursor: selected && !readOnly && moveEnabled && !locked
                ? SystemMouseCursors.move
                : SystemMouseCursors.click,
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? colorScheme.primary : borderColor,
                  width: selected ? math.max(2, borderWidth) : borderWidth,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: bytes == null
                  ? const Center(child: Icon(Icons.broken_image_outlined))
                  : Image.memory(bytes, fit: BoxFit.fill),
            ),
          );
        }

        final handleSet = <fbt.HandlePosition>{
          fbt.HandlePosition.topLeft,
          fbt.HandlePosition.top,
          fbt.HandlePosition.topRight,
          fbt.HandlePosition.left,
          fbt.HandlePosition.right,
          fbt.HandlePosition.bottomLeft,
          fbt.HandlePosition.bottom,
          fbt.HandlePosition.bottomRight,
        };
        final transformableImage = selected && !readOnly && !locked
            ? fbt.TransformableBox(
                rect: imageRect,
                clampingRect: Rect.fromLTWH(0, 0, blockWidth, clampingHeight),
                constraints: BoxConstraints(
                  minWidth: 80,
                  minHeight: 60,
                  maxWidth: maxImageWidth,
                  maxHeight: 900,
                ),
                resizeModeResolver: () => fbt.ResizeMode.freeform,
                draggable: moveEnabled,
                resizable: true,
                allowFlippingWhileResizing: false,
                enabledHandles: handleSet,
                visibleHandles: handleSet,
                onTap: handleImageVisualTap,
                onDragUpdate: (result, event) {
                  if (!moveEnabled) {
                    return;
                  }
                  if (event.delta.dy < -1.5) {
                    onMoveRequest?.call(-1);
                  } else if (event.delta.dy > 1.5) {
                    onMoveRequest?.call(1);
                  }
                },
                onChanged: (result, event) => applyTransformRect(result.rect),
                cornerHandleBuilder: richImageTransformHandle,
                sideHandleBuilder: richImageTransformHandle,
                contentBuilder: (context, rect, flip) =>
                    buildImageBox(rect.size),
              )
            : Positioned(
                left: imageRect.left,
                top: imageRect.top,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: handleImageVisualTap,
                  child: buildImageBox(imageRect.size),
                ),
              );
        return SizedBox(
          width: blockWidth,
          height: imageBlockHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: handleImageBlockBackgroundTap,
                  child: const SizedBox.expand(),
                ),
              ),
              transformableImage,
            ],
          ),
        );
      },
    );
  }
}

Widget richImageTransformHandle(
  BuildContext context,
  fbt.HandlePosition handle,
) {
  return Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        border: Border.all(color: Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const SizedBox(width: 14, height: 14),
    ),
  );
}

class InlineRichAttachmentBlock extends StatelessWidget {
  const InlineRichAttachmentBlock({
    super.key,
    required this.attachment,
    required this.selected,
    required this.readOnly,
    required this.onSelect,
    required this.onChanged,
  });

  final Map<String, dynamic> attachment;
  final bool selected;
  final bool readOnly;
  final VoidCallback onSelect;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = readInt(attachment['size']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ActionChip(
        avatar: Icon(
          Icons.attach_file,
          color: selected ? colorScheme.onPrimaryContainer : null,
        ),
        label: Text(
          '${readString(attachment['name'], fallback: '附件')}'
          '${size > 0 ? ' · ${formatFileSize(size)}' : ''}',
        ),
        onPressed: onSelect,
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        backgroundColor: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLowest,
      ),
    );
  }
}

class RichImageEditToolbar extends StatefulWidget {
  const RichImageEditToolbar({
    super.key,
    required this.image,
    required this.moveEnabled,
    required this.onImageChanged,
    required this.onMoveEnabledChanged,
    required this.onCrop,
    required this.onDelete,
    required this.onDone,
  });

  final Map<String, dynamic> image;
  final bool moveEnabled;
  final ValueChanged<Map<String, dynamic>> onImageChanged;
  final ValueChanged<bool> onMoveEnabledChanged;
  final VoidCallback onCrop;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  State<RichImageEditToolbar> createState() => _RichImageEditToolbarState();
}

class _RichImageEditToolbarState extends State<RichImageEditToolbar> {
  Map<String, dynamic> get image => widget.image;
  ValueChanged<Map<String, dynamic>> get onImageChanged =>
      widget.onImageChanged;
  VoidCallback get onCrop => widget.onCrop;
  VoidCallback get onDelete => widget.onDelete;
  VoidCallback get onDone => widget.onDone;

  void setValue(String key, Object value) {
    widget.onImageChanged({...widget.image, key: value});
  }

  Future<void> editBorderWidth() async {
    final current = readDouble(widget.image['borderWidth']);
    final controller = TextEditingController(
      text: current == current.roundToDouble()
          ? current.toStringAsFixed(0)
          : current.toStringAsFixed(1),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('框線線徑'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            suffixText: 'px',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              Navigator.pop(context, parsed);
            },
            child: const Text('套用'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      setValue('borderWidth', value.clamp(0.0, 24.0).toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderWidth = readDouble(widget.image['borderWidth']);
    final alignment = readEnum(
      NoteImageAlignment.values,
      widget.image['alignment'],
      NoteImageAlignment.left,
    );
    return _RichAssetToolbarShell(
      children: [
        RichToolbarIconButton(
          tooltip: '裁切',
          icon: Icons.crop,
          onPressed: onCrop,
        ),
        RichToolbarIconButton(
          tooltip: '縮小',
          icon: Icons.open_with,
          active: alignment == NoteImageAlignment.free,
          onPressed: () => setValue('alignment', NoteImageAlignment.free.name),
        ),
        RichToolbarIconButton(
          tooltip: '放大',
          icon: Icons.add,
          onPressed: () {
            onImageChanged({
              ...image,
              'width': readDouble(image['width'], fallback: 240) + 24,
              'height': readDouble(image['height'], fallback: 160) + 16,
            });
          },
        ),
        RichToolbarMenuButton<double>(
          label: '框 $borderWidth',
          tooltip: '框線線徑',
          values: const [0, 1, 2, 4],
          labelBuilder: (value) => value.toStringAsFixed(0),
          onSelected: (value) => setValue('borderWidth', value),
        ),
        RichToolbarColorButton(
          tooltip: '框線顏色',
          selectedColor: readString(image['borderColor'], fallback: '#5967D8'),
          values: const ['#5967D8', '#202522', '#D92D20', '#16803C'],
          onSelected: (value) => setValue('borderColor', value),
        ),
        RichToolbarIconButton(
          tooltip: '靠左',
          icon: Icons.format_align_left,
          active: alignment == NoteImageAlignment.left,
          onPressed: () => setValue('alignment', NoteImageAlignment.left.name),
        ),
        RichToolbarIconButton(
          tooltip: '置中',
          icon: Icons.format_align_center,
          active: alignment == NoteImageAlignment.center,
          onPressed: () =>
              setValue('alignment', NoteImageAlignment.center.name),
        ),
        RichToolbarIconButton(
          tooltip: '靠右',
          icon: Icons.format_align_right,
          active: alignment == NoteImageAlignment.right,
          onPressed: () => setValue('alignment', NoteImageAlignment.right.name),
        ),
        RichToolbarIconButton(
          tooltip: '自由移動',
          icon: Icons.open_with,
          active: alignment == NoteImageAlignment.free,
          onPressed: () => setValue('alignment', NoteImageAlignment.free.name),
        ),
        RichToolbarIconButton(
          tooltip: '刪除圖片',
          icon: Icons.delete_outline,
          onPressed: onDelete,
        ),
        RichToolbarIconButton(
          tooltip: '完成',
          icon: Icons.check,
          onPressed: onDone,
        ),
      ],
    );
  }
}

class ModernRichImageEditToolbar extends StatefulWidget {
  const ModernRichImageEditToolbar({
    super.key,
    required this.image,
    required this.moveEnabled,
    required this.onImageChanged,
    required this.onMoveEnabledChanged,
    required this.onCrop,
    required this.onDelete,
    required this.onDone,
  });

  final Map<String, dynamic> image;
  final bool moveEnabled;
  final ValueChanged<Map<String, dynamic>> onImageChanged;
  final ValueChanged<bool> onMoveEnabledChanged;
  final VoidCallback onCrop;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  State<ModernRichImageEditToolbar> createState() =>
      _ModernRichImageEditToolbarState();
}

class _ModernRichImageEditToolbarState
    extends State<ModernRichImageEditToolbar> {
  bool showColorToolbar = false;
  bool showBorderToolbar = false;
  late final TextEditingController borderWidthController;

  static const borderColors = [
    '#202522',
    '#FFFFFF',
    '#8A8F98',
    '#5967D8',
    '#D92D20',
    '#F79009',
    '#FEE440',
    '#16803C',
    '#12B5CB',
  ];

  @override
  void initState() {
    super.initState();
    borderWidthController = TextEditingController(text: formattedBorderWidth);
  }

  @override
  void didUpdateWidget(covariant ModernRichImageEditToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final imageChanged =
        readString(oldWidget.image['id']) != readString(widget.image['id']);
    final widthChanged =
        readDouble(oldWidget.image['borderWidth']) !=
        readDouble(widget.image['borderWidth']);
    if (imageChanged || (!showBorderToolbar && widthChanged)) {
      borderWidthController.text = formattedBorderWidth;
    }
  }

  @override
  void dispose() {
    borderWidthController.dispose();
    super.dispose();
  }

  String get formattedBorderWidth {
    final current = readDouble(widget.image['borderWidth']);
    return current == current.roundToDouble()
        ? current.toStringAsFixed(0)
        : current.toStringAsFixed(1);
  }

  void setValue(String key, Object value) {
    widget.onImageChanged({...widget.image, key: value});
  }

  void lockImage() {
    widget.onMoveEnabledChanged(false);
    setState(() {
      showBorderToolbar = false;
      showColorToolbar = false;
    });
    setValue('locked', true);
  }

  void toggleBorderWidthEditor() {
    setState(() {
      showBorderToolbar = !showBorderToolbar;
      if (showBorderToolbar) {
        showColorToolbar = false;
        borderWidthController.text = formattedBorderWidth;
      }
    });
  }

  void cancelBorderWidthEdit() {
    setState(() {
      borderWidthController.text = formattedBorderWidth;
      showBorderToolbar = false;
    });
  }

  void applyBorderWidthEdit() {
    final parsed = double.tryParse(borderWidthController.text.trim());
    setValue('borderWidth', (parsed ?? 0).clamp(0.0, 24.0).toDouble());
    setState(() => showBorderToolbar = false);
  }

  Future<void> editBorderWidth() async {
    final current = readDouble(widget.image['borderWidth']);
    final controller = TextEditingController(
      text: current == current.roundToDouble()
          ? current.toStringAsFixed(0)
          : current.toStringAsFixed(1),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('框線線徑'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            suffixText: 'px',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              Navigator.pop(context, parsed);
            },
            child: const Text('套用'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      setValue('borderWidth', value.clamp(0.0, 24.0).toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.image['locked'] == true;
    if (locked) {
      return _RichAssetToolbarShell(
        children: [
          RichToolbarIconButton(
            tooltip: '解除鎖定',
            icon: Icons.lock,
            active: true,
            onPressed: () => setValue('locked', false),
          ),
        ],
      );
    }

    final borderWidth = readDouble(widget.image['borderWidth']);
    final borderColor = readString(
      widget.image['borderColor'],
      fallback: '#5967D8',
    );
    final alignment = readEnum(
      NoteImageAlignment.values,
      widget.image['alignment'],
      NoteImageAlignment.left,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RichAssetToolbarShell(
          children: [
            RichToolbarIconButton(
              tooltip: '裁切',
              icon: Icons.crop,
              onPressed: widget.onCrop,
            ),
            RichToolbarIconButton(
              tooltip: '移動',
              icon: Icons.open_with,
              active: widget.moveEnabled,
              onPressed: () => widget.onMoveEnabledChanged(!widget.moveEnabled),
            ),
            RichToolbarIconButton(
              tooltip: '框線線徑 ${borderWidth.toStringAsFixed(1)}',
              icon: Icons.border_outer,
              active: showBorderToolbar || borderWidth > 0,
              onPressed: toggleBorderWidthEditor,
            ),
            RichToolbarColorToggleButton(
              tooltip: '框線顏色',
              selectedColor: borderColor,
              active: showColorToolbar,
              onPressed: () => setState(() {
                showColorToolbar = !showColorToolbar;
                if (showColorToolbar) {
                  showBorderToolbar = false;
                }
              }),
            ),
            RichToolbarIconButton(
              tooltip: '靠左',
              icon: Icons.format_align_left,
              active: alignment == NoteImageAlignment.left,
              onPressed: () =>
                  setValue('alignment', NoteImageAlignment.left.name),
            ),
            RichToolbarIconButton(
              tooltip: '置中',
              icon: Icons.format_align_center,
              active: alignment == NoteImageAlignment.center,
              onPressed: () =>
                  setValue('alignment', NoteImageAlignment.center.name),
            ),
            RichToolbarIconButton(
              tooltip: '靠右',
              icon: Icons.format_align_right,
              active: alignment == NoteImageAlignment.right,
              onPressed: () =>
                  setValue('alignment', NoteImageAlignment.right.name),
            ),
            RichToolbarIconButton(
              tooltip: '鎖定圖片',
              icon: Icons.lock_open,
              onPressed: lockImage,
            ),
            RichToolbarIconButton(
              tooltip: '刪除圖片',
              icon: Icons.delete_outline,
              onPressed: widget.onDelete,
            ),
            RichToolbarIconButton(
              tooltip: '完成',
              icon: Icons.check,
              onPressed: widget.onDone,
            ),
          ],
        ),
        if (showBorderToolbar) ...[
          const SizedBox(height: 6),
          _RichAssetToolbarShell(
            children: [
              SizedBox(
                width: 112,
                height: 40,
                child: TextField(
                  controller: borderWidthController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onSubmitted: (_) => applyBorderWidthEdit(),
                  decoration: const InputDecoration(
                    suffixText: 'px',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              RichToolbarIconButton(
                tooltip: '取消',
                icon: Icons.close,
                onPressed: cancelBorderWidthEdit,
              ),
              RichToolbarIconButton(
                tooltip: '套用',
                icon: Icons.check,
                onPressed: applyBorderWidthEdit,
              ),
            ],
          ),
        ],
        if (showColorToolbar) ...[
          const SizedBox(height: 6),
          _RichAssetToolbarShell(
            children: [
              for (final color in borderColors)
                RichToolbarColorChoiceButton(
                  color: color,
                  selected: borderColor.toUpperCase() == color.toUpperCase(),
                  onPressed: () {
                    setValue('borderColor', color);
                    setState(() => showColorToolbar = false);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class RichAttachmentEditToolbar extends StatelessWidget {
  const RichAttachmentEditToolbar({
    super.key,
    required this.attachment,
    required this.onOpen,
    required this.onDownload,
    required this.onDelete,
    required this.onDone,
  });

  final Map<String, dynamic> attachment;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _RichAssetToolbarShell(
      children: [
        RichToolbarIconButton(
          tooltip: '開啟',
          icon: Icons.open_in_new,
          onPressed: onOpen,
        ),
        RichToolbarIconButton(
          tooltip: '下載',
          icon: Icons.download_outlined,
          onPressed: onDownload,
        ),
        RichToolbarIconButton(
          tooltip: '刪除附件',
          icon: Icons.delete_outline,
          onPressed: onDelete,
        ),
        RichToolbarIconButton(
          tooltip: '完成',
          icon: Icons.check,
          onPressed: onDone,
        ),
      ],
    );
  }
}

class _RichAssetToolbarShell extends StatefulWidget {
  const _RichAssetToolbarShell({required this.children});

  final List<Widget> children;

  @override
  State<_RichAssetToolbarShell> createState() => _RichAssetToolbarShellState();
}

class _RichAssetToolbarShellState extends State<_RichAssetToolbarShell> {
  final ScrollController scrollController = ScrollController();
  bool canScrollLeft = false;
  bool canScrollRight = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(updateScrollButtons);
  }

  @override
  void didUpdateWidget(covariant _RichAssetToolbarShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleScrollButtonUpdate();
  }

  @override
  void dispose() {
    scrollController.removeListener(updateScrollButtons);
    scrollController.dispose();
    super.dispose();
  }

  void updateScrollButtons() {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    final nextLeft = position.pixels > 1;
    final nextRight = position.pixels < position.maxScrollExtent - 1;
    if (nextLeft != canScrollLeft || nextRight != canScrollRight) {
      setState(() {
        canScrollLeft = nextLeft;
        canScrollRight = nextRight;
      });
    }
  }

  void scheduleScrollButtonUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        updateScrollButtons();
      }
    });
  }

  void scrollBy(double delta) {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    scrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleScrollButtonUpdate();
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (canScrollLeft)
              RichToolbarScrollButton(
                tooltip: '向左捲動',
                icon: Icons.chevron_left,
                onPressed: () => scrollBy(-260),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.children,
                  ),
                ),
              ),
            ),
            if (canScrollRight)
              RichToolbarScrollButton(
                tooltip: '向右捲動',
                icon: Icons.chevron_right,
                onPressed: () => scrollBy(260),
              ),
          ],
        ),
      ),
    );
  }
}

class RichTextTemplateToolbar extends StatefulWidget {
  const RichTextTemplateToolbar({
    super.key,
    required this.controller,
    required this.style,
    required this.runEditorAction,
    required this.onStyleChanged,
    required this.onAddImage,
    required this.onAddAttachment,
    required this.onInsertTodo,
  });

  final RichNoteTextController controller;
  final Map<String, dynamic> style;
  final void Function(VoidCallback action) runEditorAction;
  final ValueChanged<Map<String, dynamic>> onStyleChanged;
  final VoidCallback onAddImage;
  final VoidCallback onAddAttachment;
  final VoidCallback onInsertTodo;

  @override
  State<RichTextTemplateToolbar> createState() =>
      _RichTextTemplateToolbarState();
}

class _RichTextTemplateToolbarState extends State<RichTextTemplateToolbar> {
  final ScrollController toolbarScrollController = ScrollController();
  bool canScrollLeft = false;
  bool canScrollRight = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
    toolbarScrollController.addListener(updateScrollButtons);
  }

  @override
  void didUpdateWidget(covariant RichTextTemplateToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(refresh);
      widget.controller.addListener(refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(refresh);
    toolbarScrollController.removeListener(updateScrollButtons);
    toolbarScrollController.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void runAction(VoidCallback action) {
    widget.runEditorAction(action);
  }

  void applyInline(String attribute, Object value) {
    runAction(() => widget.controller.applyInlineAttribute(attribute, value));
  }

  void setInline(String attribute, Object value) {
    runAction(() => widget.controller.setInlineAttribute(attribute, value));
  }

  void applyLine(String attribute, Object value) {
    runAction(() => widget.controller.applyLineAttribute(attribute, value));
  }

  void updateScrollButtons() {
    if (!toolbarScrollController.hasClients) {
      return;
    }
    final position = toolbarScrollController.position;
    final nextLeft = position.pixels > 1;
    final nextRight = position.pixels < position.maxScrollExtent - 1;
    if (nextLeft != canScrollLeft || nextRight != canScrollRight) {
      setState(() {
        canScrollLeft = nextLeft;
        canScrollRight = nextRight;
      });
    }
  }

  void scheduleScrollButtonUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        updateScrollButtons();
      }
    });
  }

  void scrollToolbar(double delta) {
    if (!toolbarScrollController.hasClients) {
      return;
    }
    final position = toolbarScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    toolbarScrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleScrollButtonUpdate();
    final colorScheme = Theme.of(context).colorScheme;
    final fontFamily = readString(
      widget.controller.selectionAttributeValue(RichNoteAttribute.fontFamily),
      fallback: readString(widget.style['fontFamily'], fallback: 'System'),
    );
    final fontSize = readDouble(
      widget.controller.selectionAttributeValue(RichNoteAttribute.fontSize),
      fallback: readDouble(widget.style['fontSize'], fallback: 16),
    ).round();
    final lineHeight = readDouble(widget.style['lineHeight'], fallback: 1.45);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (canScrollLeft)
              RichToolbarScrollButton(
                tooltip: '向左',
                icon: Icons.chevron_left,
                onPressed: () => scrollToolbar(-260),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: toolbarScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichToolbarIconButton(
                      tooltip: '復原',
                      icon: Icons.undo,
                      enabled: widget.controller.canUndoRichChange,
                      onPressed: () =>
                          runAction(widget.controller.undoRichChange),
                    ),
                    RichToolbarIconButton(
                      tooltip: '再製',
                      icon: Icons.redo,
                      enabled: widget.controller.canRedoRichChange,
                      onPressed: () =>
                          runAction(widget.controller.redoRichChange),
                    ),
                    RichToolbarFontSizeButton(
                      currentSize: fontSize.toDouble(),
                      tooltip: '字級',
                      onSelected: (value) =>
                          setInline(RichNoteAttribute.fontSize, value),
                    ),
                    RichToolbarMenuButton<String>(
                      label: noteFontFamilyLabel(fontFamily),
                      tooltip: '字型',
                      values: noteFontFamilyValues,
                      labelBuilder: noteFontFamilyLabel,
                      onSelected: (value) =>
                          setInline(RichNoteAttribute.fontFamily, value),
                    ),
                    RichToolbarTextButton(
                      label: 'B',
                      tooltip: '粗體',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.bold,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.bold, true),
                    ),
                    RichToolbarIconButton(
                      tooltip: '斜體',
                      icon: Icons.format_italic,
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.italic,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.italic, true),
                    ),
                    RichToolbarIconButton(
                      tooltip: '底線',
                      icon: Icons.format_underlined,
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.underline,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.underline, true),
                    ),
                    RichToolbarIconButton(
                      tooltip: '刪除線',
                      icon: Icons.format_strikethrough,
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.strikethrough,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.strikethrough, true),
                    ),
                    RichToolbarTextButton(
                      label: '<>',
                      tooltip: '行內程式碼',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.inlineCode,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.inlineCode, true),
                    ),
                    RichToolbarTextButton(
                      label: 'X₂',
                      tooltip: '下標',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.subscript,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.subscript, true),
                    ),
                    RichToolbarTextButton(
                      label: 'X²',
                      tooltip: '上標',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.superscript,
                        value: true,
                      ),
                      onPressed: () =>
                          applyInline(RichNoteAttribute.superscript, true),
                    ),
                    const RichToolbarDivider(),
                    RichToolbarMenuButton<double>(
                      label: lineHeight.toStringAsFixed(2),
                      tooltip: '行距',
                      values: const [1.2, 1.45, 1.7, 2.0],
                      labelBuilder: (value) => value.toStringAsFixed(2),
                      onSelected: (value) => runAction(
                        () => widget.onStyleChanged({
                          ...widget.style,
                          'lineHeight': value,
                        }),
                      ),
                    ),
                    const RichToolbarDivider(),
                    RichToolbarIconButton(
                      tooltip: '編號清單',
                      icon: Icons.format_list_numbered,
                      onPressed: () =>
                          runAction(widget.controller.applyOrderedList),
                    ),
                    RichToolbarIconButton(
                      tooltip: '項目清單',
                      icon: Icons.format_list_bulleted,
                      onPressed: () => runAction(
                        () => widget.controller.prefixSelectedLines('• '),
                      ),
                    ),
                    RichToolbarIconButton(
                      tooltip: '待辦清單',
                      icon: Icons.check_box,
                      onPressed: () =>
                          runAction(widget.controller.insertTodoCheckbox),
                    ),
                    RichToolbarTextButton(
                      label: '<>',
                      tooltip: '程式碼區塊',
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.codeBlock,
                        value: true,
                      ),
                      onPressed: () =>
                          applyLine(RichNoteAttribute.codeBlock, true),
                    ),
                    const RichToolbarDivider(),
                    RichToolbarIconButton(
                      tooltip: '引用',
                      icon: Icons.format_quote,
                      active: widget.controller.selectionHasAttribute(
                        RichNoteAttribute.quote,
                        value: true,
                      ),
                      onPressed: () => applyLine(RichNoteAttribute.quote, true),
                    ),
                    RichToolbarIconButton(
                      tooltip: '增加縮排',
                      icon: Icons.format_indent_increase,
                      onPressed: () => runAction(
                        () => widget.controller.prefixSelectedLines('  '),
                      ),
                    ),
                    RichToolbarIconButton(
                      tooltip: '減少縮排',
                      icon: Icons.format_indent_decrease,
                      onPressed: () =>
                          runAction(widget.controller.outdentSelectedLines),
                    ),
                    const RichToolbarDivider(),
                    RichToolbarIconButton(
                      tooltip: '上傳圖片',
                      icon: Icons.image_outlined,
                      onPressed: () => runAction(widget.onAddImage),
                    ),
                    RichToolbarIconButton(
                      tooltip: '上傳附件',
                      icon: Icons.attach_file,
                      onPressed: () => runAction(widget.onAddAttachment),
                    ),
                    RichToolbarIconButton(
                      tooltip: '插入待辦',
                      icon: Icons.add_task,
                      onPressed: () => runAction(widget.onInsertTodo),
                    ),
                  ],
                ),
              ),
            ),
            if (canScrollRight)
              RichToolbarScrollButton(
                tooltip: '向右',
                icon: Icons.chevron_right,
                onPressed: () => scrollToolbar(260),
              ),
          ],
        ),
      ),
    );
  }
}

class RichToolbarIconButton extends StatelessWidget {
  const RichToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      color: active ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      disabledColor: colorScheme.onSurface.withValues(alpha: 0.32),
      style: IconButton.styleFrom(
        backgroundColor: active ? colorScheme.primaryContainer : null,
      ),
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 48),
      icon: Icon(icon),
    );
  }
}

class RichToolbarTextButton extends StatelessWidget {
  const RichToolbarTextButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              width: 42,
              height: 48,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RichToolbarScrollButton extends StatelessWidget {
  const RichToolbarScrollButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: colorScheme.primary,
      iconSize: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 48),
      icon: Icon(icon),
    );
  }
}

class RichToolbarColorToggleButton extends StatelessWidget {
  const RichToolbarColorToggleButton({
    super.key,
    required this.tooltip,
    required this.selectedColor,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final String selectedColor;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: 42,
            height: 48,
            child: Center(
              child: _ColorSwatch(value: selectedColor, selected: true),
            ),
          ),
        ),
      ),
    );
  }
}

class RichToolbarColorChoiceButton extends StatelessWidget {
  const RichToolbarColorChoiceButton({
    super.key,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: colorLabel(color),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 48,
          child: Center(
            child: _ColorSwatch(value: color, selected: selected),
          ),
        ),
      ),
    );
  }
}

class RichToolbarColorButton extends StatelessWidget {
  const RichToolbarColorButton({
    super.key,
    required this.tooltip,
    required this.selectedColor,
    required this.values,
    required this.onSelected,
  });

  final String tooltip;
  final String selectedColor;
  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = selectedColor.toUpperCase();
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in values)
          PopupMenuItem<String>(
            value: value,
            child: Row(
              children: [
                _ColorSwatch(
                  value: value,
                  selected: selected == value.toUpperCase(),
                ),
                const SizedBox(width: 10),
                Text(colorLabel(value)),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: 42,
        height: 48,
        child: Center(
          child: _ColorSwatch(value: selectedColor, selected: true),
        ),
      ),
    );
  }
}

class RichToolbarFontSizeButton extends StatelessWidget {
  const RichToolbarFontSizeButton({
    super.key,
    required this.currentSize,
    required this.tooltip,
    required this.onSelected,
  });

  static const values = [10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30];

  final double currentSize;
  final String tooltip;
  final ValueChanged<double> onSelected;

  Future<void> openPicker(BuildContext context) async {
    final controller = TextEditingController(
      text: currentSize.round().toString(),
    );
    final picked = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('字級'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '輸入字級',
                    suffixText: 'pt',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      Navigator.pop(dialogContext, parsed);
                    }
                  },
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in values)
                      ChoiceChip(
                        selected: currentSize.round() == value,
                        label: Text('$value'),
                        onSelected: (_) =>
                            Navigator.pop(dialogContext, value.toDouble()),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text);
                if (parsed != null) {
                  Navigator.pop(dialogContext, parsed);
                }
              },
              child: const Text('套用'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (picked == null) {
      return;
    }
    onSelected(picked.clamp(6.0, 96.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openPicker(context),
        child: SizedBox(
          width: 86,
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  currentSize.round().toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                color: colorScheme.onSurface,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.value, required this.selected});

  final String value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(value);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 3 : 1,
        ),
      ),
    );
  }
}

class RichToolbarMenuButton<T> extends StatelessWidget {
  const RichToolbarMenuButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.values,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String label;
  final String tooltip;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: PopupMenuButton<T>(
        color: colorScheme.surface,
        tooltip: tooltip,
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final value in values)
            PopupMenuItem<T>(
              value: value,
              child: Text(
                labelBuilder(value),
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
        ],
        child: SizedBox(
          width: 86,
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                color: colorScheme.onSurface,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RichToolbarDivider extends StatelessWidget {
  const RichToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class NoteEditorToolbar extends StatelessWidget {
  const NoteEditorToolbar({
    super.key,
    required this.style,
    required this.imageCount,
    required this.attachmentCount,
    required this.onStyleChanged,
    required this.onAddImage,
    required this.onAddAttachment,
    required this.onInsertTodo,
  });

  final Map<String, dynamic> style;
  final int imageCount;
  final int attachmentCount;
  final ValueChanged<Map<String, dynamic>> onStyleChanged;
  final VoidCallback onAddImage;
  final VoidCallback onAddAttachment;
  final VoidCallback onInsertTodo;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xff5967d8)),
              const SizedBox(width: 8),
              Text(
                '編輯工具',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '字型、大小、顏色、行高',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xff687386),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownMenu<String>(
                initialSelection: readString(
                  style['fontFamily'],
                  fallback: 'System',
                ),
                label: const Text('字型'),
                width: 132,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'System', label: '系統'),
                  DropdownMenuEntry(value: 'Serif', label: '襯線'),
                  DropdownMenuEntry(value: 'Mono', label: '等寬'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    onStyleChanged({...style, 'fontFamily': value});
                  }
                },
              ),
              DropdownMenu<double>(
                initialSelection: readDouble(style['fontSize'], fallback: 16),
                label: const Text('大小'),
                width: 112,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 14, label: '14'),
                  DropdownMenuEntry(value: 16, label: '16'),
                  DropdownMenuEntry(value: 18, label: '18'),
                  DropdownMenuEntry(value: 22, label: '22'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    onStyleChanged({...style, 'fontSize': value});
                  }
                },
              ),
              DropdownMenu<String>(
                initialSelection: readString(
                  style['color'],
                  fallback: '#202522',
                ),
                label: const Text('顏色'),
                width: 128,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: '#202522', label: '黑色'),
                  DropdownMenuEntry(value: '#8B2F2F', label: '紅色'),
                  DropdownMenuEntry(value: '#235A93', label: '藍色'),
                  DropdownMenuEntry(value: '#4F6F35', label: '綠色'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    onStyleChanged({...style, 'color': value});
                  }
                },
              ),
              DropdownMenu<double>(
                initialSelection: readDouble(
                  style['lineHeight'],
                  fallback: 1.45,
                ),
                label: const Text('行高'),
                width: 112,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 1.2, label: '1.2'),
                  DropdownMenuEntry(value: 1.45, label: '1.45'),
                  DropdownMenuEntry(value: 1.7, label: '1.7'),
                  DropdownMenuEntry(value: 2.0, label: '2.0'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    onStyleChanged({...style, 'lineHeight': value});
                  }
                },
              ),
              IconButton.filledTonal(
                tooltip: '上傳圖片',
                onPressed: onAddImage,
                icon: const Icon(Icons.image_outlined),
              ),
              IconButton.filledTonal(
                tooltip: '上傳附件',
                onPressed: onAddAttachment,
                icon: const Icon(Icons.attach_file),
              ),
              IconButton.filledTonal(
                tooltip: '插入待辦',
                onPressed: onInsertTodo,
                icon: const Icon(Icons.check_box_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NoteTemplateFields extends StatelessWidget {
  const NoteTemplateFields({
    super.key,
    required this.type,
    required this.data,
    required this.onChanged,
  });

  final NoteTemplateType type;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void setValue(String key, Object? value) {
    onChanged({...data, key: value});
  }

  @override
  Widget build(BuildContext context) {
    if (type == NoteTemplateType.general) {
      return const SizedBox.shrink();
    }
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(noteTemplateIcon(type)),
              const SizedBox(width: 8),
              Text(
                noteTemplateLabel(type),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...switch (type) {
            NoteTemplateType.plan => buildPlanFields(),
            NoteTemplateType.mindMap => buildMindMapFields(),
            NoteTemplateType.lifeSheet => buildLifeSheetFields(),
            NoteTemplateType.general => <Widget>[],
          },
        ],
      ),
    );
  }

  List<Widget> buildPlanFields() {
    final tasks = readMapList(data['tasks']);
    final done = tasks.where((item) => item['done'] == true).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    return [
      TemplateTextField(
        label: '目標',
        value: readString(data['goal']),
        onChanged: (value) => setValue('goal', value),
      ),
      TemplateTextField(
        label: '階段',
        value: readString(data['phase']),
        onChanged: (value) => setValue('phase', value),
      ),
      TemplateTextField(
        label: '任務',
        value: tasks
            .map(
              (item) => '${item['done'] == true ? 'x ' : ''}${item['title']}',
            )
            .join('\n'),
        minLines: 3,
        onChanged: (value) {
          setValue(
            'tasks',
            value
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .map(
                  (line) => {
                    'title': line.replaceFirst(RegExp(r'^x\s+'), '').trim(),
                    'done': line.trim().toLowerCase().startsWith('x '),
                  },
                )
                .toList(),
          );
        },
      ),
      LinearProgressIndicator(value: progress),
      const SizedBox(height: 8),
      Text('完成率 ${(progress * 100).round()}%'),
      TemplateTextField(
        label: '開始日期',
        value: readString(data['startDate']),
        onChanged: (value) => setValue('startDate', value),
      ),
      TemplateTextField(
        label: '截止日期',
        value: readString(data['dueDate']),
        onChanged: (value) => setValue('dueDate', value),
      ),
      TemplateTextField(
        label: '進行時間',
        value: readString(data['spentHours'], fallback: '0'),
        onChanged: (value) =>
            setValue('spentHours', double.tryParse(value) ?? 0),
      ),
      TemplateTextField(
        label: '備註',
        value: readString(data['notes']),
        minLines: 2,
        onChanged: (value) => setValue('notes', value),
      ),
    ];
  }

  List<Widget> buildMindMapFields() {
    return [
      TemplateTextField(
        label: '主題',
        value: readString(data['topic']),
        onChanged: (value) => setValue('topic', value),
      ),
      TemplateTextField(
        label: '節點（標題 | 次標 | 說明 | x,y | 顏色 | 展開/收合）',
        value: readMapList(data['nodes'])
            .map(
              (item) =>
                  '${item['title']} | ${item['subtitle']} | ${item['description']} | ${item['x']},${item['y']} | ${item['color']} | ${item['expanded'] == true ? '展開' : '收合'}',
            )
            .join('\n'),
        minLines: 4,
        onChanged: (value) => setValue(
          'nodes',
          value
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map(parseMindMapNodeLine)
              .toList(),
        ),
      ),
    ];
  }

  List<Widget> buildLifeSheetFields() {
    final items = readMapList(data['items']);
    final totalTarget = items.fold<double>(
      0,
      (sum, item) => sum + readDouble(item['targetAmount']),
    );
    final totalCurrent = items.fold<double>(
      0,
      (sum, item) => sum + readDouble(item['currentAmount']),
    );
    final progress = totalTarget <= 0
        ? 0.0
        : (totalCurrent / totalTarget).clamp(0.0, 1.0);
    return [
      TemplateTextField(
        label: '連結計劃',
        value: readStringList(data['linkedPlanIds']).join(', '),
        onChanged: (value) => setValue(
          'linkedPlanIds',
          value
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        ),
      ),
      TemplateTextField(
        label: '項目（名稱 | 目標金額 | 目前金額 | 實際花費）',
        value: items
            .map(
              (item) =>
                  '${item['name']} | ${item['targetAmount']} | ${item['currentAmount']} | ${item['actualCost']}',
            )
            .join('\n'),
        minLines: 4,
        onChanged: (value) => setValue(
          'items',
          value
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map(parseLifeSheetItemLine)
              .toList(),
        ),
      ),
      LinearProgressIndicator(value: progress),
      const SizedBox(height: 8),
      Text('金額對比'),
      const SizedBox(height: 8),
      SizedBox(
        height: 88,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AmountBar(label: '目標金額', value: totalTarget, maxValue: totalTarget),
            const SizedBox(width: 12),
            AmountBar(
              label: '目前金額',
              value: totalCurrent,
              maxValue: totalTarget,
            ),
          ],
        ),
      ),
      TemplateTextField(
        label: '開始時間',
        value: readString(data['startDate']),
        onChanged: (value) => setValue('startDate', value),
      ),
      TemplateTextField(
        label: '進行時間',
        value: readString(data['spentHours'], fallback: '0'),
        onChanged: (value) =>
            setValue('spentHours', double.tryParse(value) ?? 0),
      ),
      TemplateTextField(
        label: '備註',
        value: readString(data['notes']),
        minLines: 2,
        onChanged: (value) => setValue('notes', value),
      ),
    ];
  }
}

class TemplateTextField extends StatefulWidget {
  const TemplateTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int minLines;

  @override
  State<TemplateTextField> createState() => _TemplateTextFieldState();
}

class _TemplateTextFieldState extends State<TemplateTextField> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant TemplateTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && controller.text != widget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        minLines: widget.minLines,
        maxLines: widget.minLines == 1 ? 1 : null,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class NoteAssetsSummary extends StatelessWidget {
  const NoteAssetsSummary({
    super.key,
    required this.images,
    required this.attachments,
    required this.background,
    this.readOnly = false,
    required this.onImagesChanged,
    required this.onAttachmentsChanged,
  });

  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic> background;
  final bool readOnly;
  final ValueChanged<List<Map<String, dynamic>>> onImagesChanged;
  final ValueChanged<List<Map<String, dynamic>>> onAttachmentsChanged;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty &&
        attachments.isEmpty &&
        readString(background['image']).isEmpty) {
      return const SizedBox.shrink();
    }
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('附件', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final image in images)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title: Text(readString(image['name'])),
              subtitle: Text(
                '${noteImageAlignmentLabel(readEnum(NoteImageAlignment.values, image['alignment'], NoteImageAlignment.left))}  ${readDouble(image['width']).round()} x ${readDouble(image['height']).round()}',
              ),
              trailing: readOnly
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final next = List<Map<String, dynamic>>.from(images)
                          ..remove(image);
                        onImagesChanged(next);
                      },
                    ),
            ),
          for (final attachment in attachments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(readString(attachment['name'])),
              subtitle: Text(
                readString(attachment['mode']) == 'content' ? '插入內容' : '附件檔案',
              ),
              trailing: readOnly
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final next = List<Map<String, dynamic>>.from(
                          attachments,
                        )..remove(attachment);
                        onAttachmentsChanged(next);
                      },
                    ),
            ),
          if (readString(background['image']).isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('下載'),
              subtitle: Text(
                '${background['image']}  ${noteBackgroundModeLabel(readEnum(NoteBackgroundMode.values, background['mode'], NoteBackgroundMode.fill))}',
              ),
            ),
        ],
      ),
    );
  }
}

class AmountBar extends StatelessWidget {
  const AmountBar({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final heightFactor = maxValue <= 0
        ? 0.0
        : (value / maxValue).clamp(0.05, 1.0);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFactor,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

TextStyle noteBodyTextStyle(
  Map<String, dynamic> style, {
  BuildContext? context,
}) {
  final family = readString(style['fontFamily'], fallback: 'System');
  final colorValue = readString(style['color'], fallback: '#202522');
  final usesDefaultColor =
      colorValue.toUpperCase() == '#202522' || colorValue.trim().isEmpty;
  return TextStyle(
    fontFamily: family == 'System' ? null : family,
    fontSize: readDouble(style['fontSize'], fallback: 16),
    color: usesDefaultColor && context != null
        ? Theme.of(context).colorScheme.onSurface
        : colorFromHex(colorValue),
    height: readDouble(style['lineHeight'], fallback: 1.45),
  );
}

Color effectiveNoteBackgroundColor(
  BuildContext context,
  Map<String, dynamic> background,
) {
  final colorValue = readString(background['color'], fallback: '#FFFFFF');
  final usesDefaultColor =
      colorValue.toUpperCase() == '#FFFFFF' || colorValue.trim().isEmpty;
  if (usesDefaultColor) {
    return Theme.of(context).colorScheme.surface;
  }
  return colorFromHex(colorValue);
}

DecorationImage? effectiveNoteBackgroundImage(Map<String, dynamic> background) {
  if (readString(background['type'], fallback: 'color') != 'image') {
    return null;
  }
  final bytes = decodeBase64BytesOrNull(
    readString(background['imageBytesBase64']),
  );
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  final mode = readEnum(
    NoteBackgroundMode.values,
    background['mode'],
    NoteBackgroundMode.fill,
  );
  return DecorationImage(
    image: MemoryImage(bytes),
    fit: switch (mode) {
      NoteBackgroundMode.stretch => BoxFit.fill,
      NoteBackgroundMode.repeat => BoxFit.none,
      NoteBackgroundMode.fill => BoxFit.cover,
    },
    repeat: mode == NoteBackgroundMode.repeat
        ? ImageRepeat.repeat
        : ImageRepeat.noRepeat,
  );
}

Color colorFromHex(String value) {
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex.length == 6 ? 'ff$hex' : hex, radix: 16);
  return Color(parsed ?? 0xff202522);
}

String colorLabel(String value) {
  return switch (value.toUpperCase()) {
    '#5967D8' => '主題藍',
    '#202522' => '深灰',
    '#FFFFFF' => '白色',
    '#8A8F98' => '灰色',
    '#D92D20' => '紅色',
    '#F79009' => '橘色',
    '#FEE440' => '黃色',
    '#16803C' => '綠色',
    '#12B5CB' => '青色',
    _ => '自訂色',
  };
}

const noteFontFamilyValues = [
  'System',
  'NotoSansTC',
  'NotoSerifTC',
  'CascadiaCode',
];

String noteFontFamilyLabel(String value) {
  return switch (value) {
    'System' => '系統',
    'NotoSansTC' => 'Noto 黑體',
    'NotoSerifTC' => 'Noto 明體',
    'CascadiaCode' => 'Cascadia 等寬',
    _ => value,
  };
}

String fileExtension(String name) {
  final index = name.lastIndexOf('.');
  if (index < 0 || index == name.length - 1) {
    return '';
  }
  return name.substring(index + 1).toLowerCase();
}

bool isImageFileName(String name) {
  return const {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
  }.contains(fileExtension(name));
}

bool isTextLikeFileName(String name) {
  return const {
    'txt',
    'md',
    'markdown',
    'json',
    'csv',
    'tsv',
    'xml',
    'html',
    'css',
    'js',
    'ts',
    'dart',
    'yaml',
    'yml',
    'log',
  }.contains(fileExtension(name));
}

String? safeUtf8Preview(Uint8List bytes, {int limit = 24000}) {
  try {
    final sample = bytes.take(limit).toList(growable: false);
    final text = utf8.decode(sample, allowMalformed: false);
    final controlCount = text.runes.where((rune) {
      return rune < 32 && rune != 9 && rune != 10 && rune != 13;
    }).length;
    if (controlCount > math.max(4, text.length ~/ 80)) {
      return null;
    }
    return text;
  } catch (_) {
    return null;
  }
}

class NoteFileService {
  const NoteFileService._();

  static Future<PlatformFile?> pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    return result?.files.single;
  }

  static Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );
    return result?.files.single;
  }

  static Future<CroppedFile?> cropImage(
    BuildContext context,
    String sourcePath,
  ) {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁切圖片',
          toolbarColor: const Color(0xff5967d8),
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.white,
          activeControlsWidgetColor: const Color(0xff5967d8),
          cropFrameColor: const Color(0xff5967d8),
          cropGridColor: const Color(0x665967d8),
          cropFrameStrokeWidth: 3,
          cropGridStrokeWidth: 1,
          showCropGrid: true,
          hideBottomControls: false,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.original,
        ),
        IOSUiSettings(
          title: '裁切圖片',
          doneButtonTitle: '✓',
          cancelButtonTitle: '✕',
        ),
        WebUiSettings(
          context: context,
          size: const CropperSize(width: 420, height: 420),
          presentStyle: WebPresentStyle.dialog,
        ),
      ],
    );
  }

  static Future<String?> saveBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: '儲存附件',
      fileName: fileName,
      bytes: bytes,
    );
  }

  static Future<Uint8List> buildNotePdf({
    required String title,
    required String body,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            title.trim().isEmpty ? '未命名筆記' : title.trim(),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text(body),
        ],
      ),
    );
    return document.save();
  }

  static Future<void> printNotePdf({
    required String title,
    required String body,
  }) async {
    final bytes = await buildNotePdf(title: title, body: body);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareNotePdf({
    required String title,
    required String body,
  }) async {
    final bytes = await buildNotePdf(title: title, body: body);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${safeExportFileName(title)}.pdf',
    );
  }

  static Future<void> shareText({
    required String title,
    required String body,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        title: title.trim().isEmpty ? 'My Note' : title.trim(),
        text: body,
      ),
    );
  }
}

String safeExportFileName(String value) {
  final clean = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
  return clean.isEmpty ? 'my_note' : clean;
}

Uint8List? decodeBase64BytesOrNull(String value) {
  if (value.trim().isEmpty) {
    return null;
  }
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

Future<Size?> decodeImageDimensions(Uint8List bytes) async {
  if (bytes.isEmpty) {
    return null;
  }
  final completer = Completer<Size?>();
  try {
    ui.decodeImageFromList(bytes, (image) {
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      if (!completer.isCompleted) {
        completer.complete(size);
      }
    });
  } catch (_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }
  return completer.future.timeout(
    const Duration(seconds: 2),
    onTimeout: () => null,
  );
}

Size fittedImageDisplaySize({
  required double boxWidth,
  required double boxHeight,
  required double naturalWidth,
  required double naturalHeight,
}) {
  if (boxWidth <= 0 ||
      boxHeight <= 0 ||
      naturalWidth <= 0 ||
      naturalHeight <= 0) {
    return Size(boxWidth, boxHeight);
  }
  final naturalRatio = naturalWidth / naturalHeight;
  final boxRatio = boxWidth / boxHeight;
  if (boxRatio > naturalRatio) {
    return Size(boxHeight * naturalRatio, boxHeight);
  }
  return Size(boxWidth, boxWidth / naturalRatio);
}

Map<String, dynamic> firstMapById(List<Map<String, dynamic>> items, String id) {
  return nullableMapById(items, id) ?? <String, dynamic>{'id': id};
}

Map<String, dynamic>? nullableMapById(
  List<Map<String, dynamic>> items,
  String id,
) {
  for (final item in items) {
    if (readString(item['id']) == id) {
      return Map<String, dynamic>.from(item);
    }
  }
  return null;
}

String formatFileSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

Map<String, dynamic> parseMindMapNodeLine(String line) {
  final parts = line.split('|').map((item) => item.trim()).toList();
  final position = parts.length > 3 ? parts[3].split(',') : const <String>[];
  return {
    'title': parts.isNotEmpty ? parts[0] : '',
    'subtitle': parts.length > 1 ? parts[1] : '',
    'description': parts.length > 2 ? parts[2] : '',
    'x': position.isNotEmpty ? double.tryParse(position[0]) ?? 0 : 0,
    'y': position.length > 1 ? double.tryParse(position[1]) ?? 0 : 0,
    'color': parts.length > 4 ? parts[4] : '#7C8B5F',
    'expanded': parts.length <= 5 || parts[5] != 'false',
  };
}

Map<String, dynamic> parseLifeSheetItemLine(String line) {
  final parts = line.split('|').map((item) => item.trim()).toList();
  return {
    'name': parts.isNotEmpty ? parts[0] : '',
    'targetAmount': parts.length > 1 ? double.tryParse(parts[1]) ?? 0 : 0,
    'currentAmount': parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0,
    'actualCost': parts.length > 3 ? double.tryParse(parts[3]) ?? 0 : 0,
  };
}

String noteTemplateLabel(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '筆記',
    NoteTemplateType.plan => '計劃',
    NoteTemplateType.mindMap => '心智圖',
    NoteTemplateType.lifeSheet => '人生試算表',
  };
}

String noteTemplateDescription(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '自由文字、圖片、附件與背景設定',
    NoteTemplateType.plan => '目標、階段、任務、進度、日期與備註',
    NoteTemplateType.mindMap => '主題、節點、座標、顏色與展開狀態',
    NoteTemplateType.lifeSheet => '計劃連結、金額目標、目前金額與圖表資料',
  };
}

String noteBodyLabel(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '內文',
    NoteTemplateType.plan => '計劃補充內容',
    NoteTemplateType.mindMap => '心智圖補充內容',
    NoteTemplateType.lifeSheet => '試算表補充內容',
  };
}

IconData noteTemplateIcon(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => Icons.notes,
    NoteTemplateType.plan => Icons.flag_outlined,
    NoteTemplateType.mindMap => Icons.account_tree_outlined,
    NoteTemplateType.lifeSheet => Icons.stacked_bar_chart,
  };
}

String noteImageAlignmentLabel(NoteImageAlignment value) {
  return switch (value) {
    NoteImageAlignment.free => '自由移動',
    NoteImageAlignment.left => '靠左',
    NoteImageAlignment.center => '置中',
    NoteImageAlignment.right => '靠右',
  };
}

String noteBackgroundModeLabel(NoteBackgroundMode value) {
  return switch (value) {
    NoteBackgroundMode.fill => '填滿',
    NoteBackgroundMode.stretch => '延伸',
    NoteBackgroundMode.repeat => '重複',
  };
}

class ScheduleEditorPage extends StatefulWidget {
  const ScheduleEditorPage({super.key, this.event, this.initialDate});

  final ScheduleItem? event;
  final DateTime? initialDate;

  @override
  State<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends State<ScheduleEditorPage> {
  late final TextEditingController title;
  late final TextEditingController location;
  late final TextEditingController notes;
  late DateTime date;
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  late int reminder;
  late DateTime initialDateValue;
  late TimeOfDay initialStartTime;
  late TimeOfDay initialEndTime;
  late int initialReminder;
  bool allowPop = false;
  bool didSave = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    title = TextEditingController(text: event?.title ?? '');
    location = TextEditingController(text: event?.location ?? '');
    notes = TextEditingController(text: event?.notes ?? '');
    date = event?.start ?? widget.initialDate ?? DateTime.now();
    final defaultStart = DateTime.now().add(const Duration(hours: 1));
    startTime = event == null
        ? timeOfDate(defaultStart)
        : timeOfDate(event.start);
    endTime = event == null
        ? timeOfDate(defaultStart.add(const Duration(hours: 1)))
        : timeOfDate(event.end);
    reminder = event?.remindBeforeMinutes ?? 30;
    initialDateValue = date;
    initialStartTime = startTime;
    initialEndTime = endTime;
    initialReminder = reminder;
  }

  @override
  void dispose() {
    title.dispose();
    location.dispose();
    notes.dispose();
    super.dispose();
  }

  bool get hasChanges {
    final event = widget.event;
    final nextTitle = title.text.trim();
    final nextLocation = location.text.trim();
    final nextNotes = notes.text.trim();
    final nextStart = combineDateAndTime(date, startTime);
    final nextEnd = combineDateAndTime(date, endTime);
    if (event == null) {
      return nextTitle.isNotEmpty ||
          nextLocation.isNotEmpty ||
          nextNotes.isNotEmpty ||
          !isSameDate(date, initialDateValue) ||
          startTime != initialStartTime ||
          endTime != initialEndTime ||
          reminder != initialReminder;
    }
    return nextTitle != event.title ||
        nextLocation != event.location ||
        nextNotes != event.notes ||
        nextStart != event.start ||
        nextEnd != event.end ||
        reminder != event.remindBeforeMinutes;
  }

  void saveSchedule() {
    if (didSave) {
      return;
    }
    if (!hasChanges) {
      didSave = true;
      return;
    }
    final store = AppStoreScope.of(context);
    final event = widget.event;
    final start = combineDateAndTime(date, startTime);
    var end = combineDateAndTime(date, endTime);
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    store.upsertSchedule(
      ScheduleItem(
        id: event?.id ?? store.newId('s'),
        title: title.text.trim().isEmpty ? '未命名行程' : title.text.trim(),
        start: start,
        end: end,
        location: location.text.trim(),
        notes: notes.text.trim(),
        remindBeforeMinutes: reminder,
      ),
    );
    didSave = true;
  }

  void saveAndExit() {
    saveSchedule();
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void discardAndExit() {
    didSave = true;
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> requestExit() async {
    if (!hasChanges) {
      discardAndExit();
      return;
    }
    final shouldSave = await confirmSaveChanges(
      context,
      title: '儲存行程？',
      message: '這筆行程有尚未儲存的變更。',
    );
    if (!mounted) {
      return;
    }
    if (shouldSave) {
      saveAndExit();
    } else {
      discardAndExit();
    }
  }

  Future<void> deleteAndExit() async {
    final event = widget.event;
    if (event == null) {
      return;
    }
    final confirmed = await confirmDelete(
      context,
      title: '刪除行程？',
      message: '確定要刪除這筆行程嗎？',
    );
    if (!confirmed || !mounted) {
      return;
    }
    AppStoreScope.of(context).deleteSchedule(event);
    didSave = true;
    allowPop = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(requestExit());
      },
      child: Scaffold(
        body: SafeArea(
          child: AppPage(
            title: widget.event == null ? '新增行程' : '編輯行程',
            subtitle: '時間、地點與提醒',
            leading: PageBackButton(onPressed: requestExit),
            actions: [
              if (widget.event != null)
                IconButton(
                  tooltip: '刪除行程',
                  onPressed: deleteAndExit,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.today),
                  title: Text(formatDate(date)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await showAppDatePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                      initialDate: date,
                    );
                    if (picked != null) {
                      setState(() => date = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('開始時間'),
                  subtitle: Text(formatTimeOfDayValue(startTime)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showAppTimePicker(
                      context,
                      initialTime: startTime,
                      helpText: '選擇開始時間',
                    );
                    if (picked != null) {
                      setState(() {
                        startTime = picked;
                        final start = combineDateAndTime(date, startTime);
                        final end = combineDateAndTime(date, endTime);
                        if (!end.isAfter(start)) {
                          endTime = timeOfDate(
                            start.add(const Duration(hours: 1)),
                          );
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.update),
                  title: const Text('結束時間'),
                  subtitle: Text(formatTimeOfDayValue(endTime)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showAppTimePicker(
                      context,
                      initialTime: endTime,
                      helpText: '選擇結束時間',
                    );
                    if (picked != null) {
                      setState(() => endTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(
                    labelText: '地點',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '備註',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownMenu<int>(
                  initialSelection: reminder,
                  label: const Text('提醒'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 0, label: '不提醒'),
                    DropdownMenuEntry(value: 10, label: '10 分鐘前'),
                    DropdownMenuEntry(value: 30, label: '30 分鐘前'),
                    DropdownMenuEntry(value: 60, label: '1 小時前'),
                    DropdownMenuEntry(value: 1440, label: '1 天前'),
                  ],
                  onSelected: (value) =>
                      setState(() => reminder = value ?? reminder),
                ),
                const SizedBox(height: 16),
                EditorActionButtons(
                  onCancel: discardAndExit,
                  onSave: saveAndExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceEditorPage extends StatefulWidget {
  const FinanceEditorPage({super.key, this.entry});

  final FinanceEntry? entry;

  @override
  State<FinanceEditorPage> createState() => _FinanceEditorPageState();
}

class _FinanceEditorPageState extends State<FinanceEditorPage> {
  late final TextEditingController title;
  late final TextEditingController amount;
  late final TextEditingController note;
  late EntryType type;
  late String category;
  late String account;
  late DateTime date;
  late final String initialTitle;
  late final String initialAmount;
  late final String initialNote;
  late final EntryType initialType;
  late final String initialCategory;
  late String initialAccount;
  late final DateTime initialDate;
  bool allowPop = false;
  bool didSave = false;
  bool syncedDefaultAccount = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    title = TextEditingController(text: entry?.title ?? '');
    amount = TextEditingController(
      text: entry == null ? '' : entry.amount.toStringAsFixed(0),
    );
    note = TextEditingController(text: entry?.note ?? '');
    type = entry?.type ?? EntryType.expense;
    category = entry?.category ?? '食物';
    account = entry?.account ?? '';
    date = entry?.date ?? DateTime.now();
    initialTitle = title.text.trim();
    initialAmount = amount.text.trim();
    initialNote = note.text.trim();
    initialType = type;
    initialCategory = category;
    initialAccount = account;
    initialDate = date;
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  bool get hasChanges {
    return title.text.trim() != initialTitle ||
        amount.text.trim() != initialAmount ||
        note.text.trim() != initialNote ||
        type != initialType ||
        category != initialCategory ||
        account != initialAccount ||
        !isSameMinute(date, initialDate);
  }

  void saveFinanceEntry() {
    if (didSave) {
      return;
    }
    final store = AppStoreScope.of(context);
    final entry = widget.entry;
    final accountOptions = financeAccountOptions(
      store,
      currentAccount: account,
      includeCurrent: entry != null,
    );
    final selectedAccount = accountOptions.contains(account)
        ? account
        : accountOptions.first;
    store.upsertFinanceEntry(
      FinanceEntry(
        id: entry?.id ?? store.newId('f'),
        type: type,
        title: title.text.trim().isEmpty ? '未命名記帳' : title.text.trim(),
        amount: double.tryParse(amount.text) ?? 0,
        category: type == EntryType.income ? '收入' : category,
        account: selectedAccount,
        date: date,
        note: note.text.trim(),
      ),
    );
    didSave = true;
  }

  void saveAndExit() {
    saveFinanceEntry();
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void discardAndExit() {
    didSave = true;
    allowPop = true;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> requestExit() async {
    if (!hasChanges) {
      discardAndExit();
      return;
    }
    final shouldSave = await confirmSaveChanges(
      context,
      title: '儲存記帳？',
      message: '這筆記帳有尚未儲存的變更。',
    );
    if (!mounted) {
      return;
    }
    if (shouldSave) {
      saveAndExit();
    } else {
      discardAndExit();
    }
  }

  Future<void> pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: date,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => date = combinePickedDateWithCurrentTime(picked, date));
  }

  Future<void> pickTime() async {
    final picked = await showAppTimePicker(
      context,
      initialTime: timeOfDate(date),
      helpText: '選擇記帳時間',
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => date = combineDateAndTime(date, picked));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final accountOptions = financeAccountOptions(
      store,
      currentAccount: account,
      includeCurrent: widget.entry != null,
    );
    if (!accountOptions.contains(account)) {
      account = accountOptions.first;
      if (widget.entry == null &&
          initialAccount.isEmpty &&
          !syncedDefaultAccount) {
        initialAccount = account;
        syncedDefaultAccount = true;
      }
    }
    Widget fieldBox(Widget child, {double width = 156}) {
      return SizedBox(width: width, child: child);
    }

    Widget metaButton({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      double width = 148,
    }) {
      return SizedBox(
        width: width,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      );
    }

    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(requestExit());
      },
      child: Scaffold(
        body: SafeArea(
          child: AppPage(
            title: widget.entry == null ? '新增記帳' : '編輯記帳',
            subtitle: '收入、支出、分類與帳戶',
            leading: PageBackButton(onPressed: requestExit),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                SegmentedButton<EntryType>(
                  segments: const [
                    ButtonSegment(
                      value: EntryType.expense,
                      label: Text('支出'),
                      icon: Icon(Icons.remove),
                    ),
                    ButtonSegment(
                      value: EntryType.income,
                      label: Text('收入'),
                      icon: Icon(Icons.add),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) =>
                      setState(() => type = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: moneyInputFormatters(),
                  decoration: const InputDecoration(
                    labelText: '金額',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (type == EntryType.expense)
                      fieldBox(
                        DropdownMenu<String>(
                          width: 156,
                          initialSelection: category,
                          label: const Text('分類'),
                          dropdownMenuEntries:
                              const ['食物', '交通', '娛樂', '訂閱', '學習', '生活', '其他']
                                  .map(
                                    (item) => DropdownMenuEntry(
                                      value: item,
                                      label: item,
                                    ),
                                  )
                                  .toList(),
                          onSelected: (value) =>
                              setState(() => category = value ?? category),
                        ),
                      ),
                    fieldBox(
                      DropdownMenu<String>(
                        width: 156,
                        initialSelection: account,
                        label: const Text('帳戶'),
                        dropdownMenuEntries: accountOptions
                            .map(
                              (item) =>
                                  DropdownMenuEntry(value: item, label: item),
                            )
                            .toList(),
                        onSelected: (value) =>
                            setState(() => account = value ?? account),
                      ),
                    ),
                    metaButton(
                      icon: Icons.today_outlined,
                      label: formatDate(date),
                      onPressed: pickDate,
                    ),
                    metaButton(
                      icon: Icons.schedule,
                      label: formatTime(date),
                      onPressed: pickTime,
                      width: 128,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '備註',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                EditorActionButtons(
                  onCancel: discardAndExit,
                  onSave: saveAndExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
