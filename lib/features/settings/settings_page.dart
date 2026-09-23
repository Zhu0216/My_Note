part of '../../main.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '設定',
      subtitle: '本機資料、提醒與未來同步規劃',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const LocalDataManagementCard(),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline),
                  title: Text('Firebase Auth'),
                  subtitle: Text('使用者登入與帳號管理'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_sync_outlined),
                  title: Text('Cloud Firestore'),
                  subtitle: Text(
                    'Notes、Schedule、Subscriptions、Finance 將以 userId 分層同步。',
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.attach_file),
                  title: Text('Firebase Storage'),
                  subtitle: Text('附件與圖片儲存'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('FCM 推播'),
                  subtitle: Text('手機推播與提醒通知'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.public),
                  title: Text('Flutter Web + Firebase Hosting'),
                  subtitle: Text('Web 部署與公開網址'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.storefront_outlined),
                  title: Text('上架準備'),
                  subtitle: Text('Google Play 與 App Store 上架準備'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.space_dashboard_outlined),
                  title: Text('介面風格'),
                  subtitle: Text('下方導覽列已套用 Nav Bars Template 6，後續可在此加入風格切換。'),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_note_outlined),
                  title: Text('筆記編輯器'),
                  subtitle: Text('一般筆記使用 Rich Text template 風格的整合編輯面板。'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocalDataManagementCard extends StatefulWidget {
  const LocalDataManagementCard({super.key});

  @override
  State<LocalDataManagementCard> createState() =>
      _LocalDataManagementCardState();
}

class _LocalDataManagementCardState extends State<LocalDataManagementCard> {
  bool busy = false;

  Future<void> exportData() async {
    setState(() => busy = true);
    try {
      final raw = await AppStoreScope.read(context).exportBundle();
      final now = DateTime.now();
      final fileName =
          'my_note_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      final location = await NoteFileService.saveBytes(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(raw)),
      );
      if (!mounted) return;
      showToast(context, location == null ? '已取消匯出' : '資料已匯出');
    } catch (_) {
      if (mounted) showToast(context, '匯出資料失敗');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('匯入本機資料？'),
        content: const Text('目前資料會先建立可復原備份，再套用選擇的匯出檔。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('匯入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      if (bytes == null) {
        if (mounted) showToast(context, '未選擇匯入檔');
        return;
      }
      if (!mounted) return;
      final result = await AppStoreScope.read(
        context,
      ).importBundle(utf8.decode(bytes, allowMalformed: false));
      if (!mounted) return;
      showToast(
        context,
        '已匯入 ${result.noteCount} 筆筆記、${result.scheduleCount} 筆行程與 ${result.todoCount} 項待辦',
      );
    } on FormatException catch (error) {
      if (mounted) showToast(context, error.message);
    } catch (_) {
      if (mounted) showToast(context, '匯入資料失敗');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showRecoveryHistory() async {
    final store = AppStoreScope.read(context);
    setState(() => busy = true);
    List<LocalBackupSnapshot> snapshots = const [];
    try {
      snapshots = await store.recoverySnapshots();
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('復原備份'),
        content: SizedBox(
          width: 420,
          child: snapshots.isEmpty
              ? const Text('目前沒有可復原的備份。')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: snapshots.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (_, index) {
                    final snapshot = snapshots[index];
                    return ListTile(
                      title: Text(
                        '${formatDate(snapshot.savedAt)} ${formatTime(snapshot.savedAt)}',
                      ),
                      subtitle: Text(
                        '${snapshot.noteCount} 筆筆記、${snapshot.scheduleCount} 筆行程、${snapshot.todoCount} 項待辦',
                      ),
                      trailing: const Icon(Icons.restore),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: dialogContext,
                          builder: (confirmContext) => AlertDialog(
                            title: const Text('復原這份備份？'),
                            content: const Text('目前資料會先建立新備份，再復原選擇的內容。'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(confirmContext, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(confirmContext, true),
                                child: const Text('復原'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !mounted) return;
                        try {
                          final result = await store.restoreRecoverySnapshot(
                            snapshot,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          showToast(
                            dialogContext,
                            '已復原 ${result.noteCount} 筆筆記、${result.scheduleCount} 筆行程與 ${result.todoCount} 項待辦',
                          );
                          Navigator.pop(dialogContext);
                        } catch (_) {
                          if (mounted && dialogContext.mounted) {
                            showToast(dialogContext, '復原備份失敗');
                          }
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: const Text('本機資料與備份'),
            subtitle: const Text('資料保留於裝置，可匯出 JSON 備份並在匯入前建立復原點。'),
          ),
          const Divider(),
          ListTile(
            enabled: !busy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('匯出資料'),
            subtitle: const Text('建立可攜 JSON 備份檔'),
            trailing: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: busy ? null : exportData,
          ),
          const Divider(),
          ListTile(
            enabled: !busy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('匯入資料'),
            subtitle: const Text('匯入 JSON 備份；目前資料會先備份'),
            onTap: busy ? null : importData,
          ),
          const Divider(),
          ListTile(
            enabled: !busy,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_outlined),
            title: const Text('復原備份'),
            subtitle: const Text('檢視並復原本機備份歷程'),
            onTap: busy ? null : showRecoveryHistory,
          ),
        ],
      ),
    );
  }
}
