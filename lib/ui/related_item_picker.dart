import 'package:flutter/material.dart';

import '../data/my_note_data.dart';
import '../data/related_item_index.dart';
import 'app_store_scope.dart';
import 'shared_components.dart';

Future<List<RelatedItemLink>?> showRelatedItemPicker(
  BuildContext context, {
  required AppStore store,
  required List<RelatedItemLink> initialLinks,
  RelatedItemLink? source,
}) => Navigator.of(context).push<List<RelatedItemLink>>(
  MaterialPageRoute(
    builder: (_) => AppStoreScope(
      store: store,
      child: RelatedItemPickerPage(initialLinks: initialLinks, source: source),
    ),
  ),
);

Future<void> showRelatedItemDetails(
  BuildContext context, {
  required AppStore store,
  required RelatedItemLink link,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AppStoreScope(
      store: store,
      child: RelatedItemDetailsPage(link: link),
    ),
  ),
);

class RelatedItemsField extends StatelessWidget {
  const RelatedItemsField({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.hub_outlined),
      title: const Text('關聯項目'),
      subtitle: Text(count == 0 ? '尚未連結其他資料' : '已連結 $count 個項目'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onPressed,
    );
  }
}

class RelatedItemPickerPage extends StatefulWidget {
  const RelatedItemPickerPage({
    super.key,
    required this.initialLinks,
    this.source,
  });

  final List<RelatedItemLink> initialLinks;
  final RelatedItemLink? source;

  @override
  State<RelatedItemPickerPage> createState() => _RelatedItemPickerPageState();
}

class _RelatedItemPickerPageState extends State<RelatedItemPickerPage> {
  late final Set<String> selectedKeys;
  late final Map<String, RelatedItemLink> selectedLinks;
  String query = '';

  @override
  void initState() {
    super.initState();
    selectedLinks = {
      for (final link in normalizeRelatedItemLinks(widget.initialLinks))
        _linkKey(link): link,
    };
    selectedKeys = selectedLinks.keys.toSet();
  }

  void toggle(RelatedItemDescriptor item) {
    setState(() {
      if (!selectedKeys.remove(item.key)) {
        selectedKeys.add(item.key);
        selectedLinks[item.key] = item.link;
      } else {
        selectedLinks.remove(item.key);
      }
    });
  }

  void finish() {
    Navigator.pop(
      context,
      normalizeRelatedItemLinks(
        selectedKeys.map((key) => selectedLinks[key]!).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final candidates = store.relatedItemCandidates(
      query: query,
      exclude: widget.source,
    );
    final reverseLinks = widget.source == null
        ? const <RelatedItemDescriptor>[]
        : store.reverseLinksTo(widget.source!);

    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: '關聯項目',
          subtitle: '搜尋並連結現有資料',
          leading: PageBackButton(onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(
              tooltip: '完成',
              onPressed: finish,
              icon: const Icon(Icons.check),
            ),
          ],
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    hintText: '搜尋筆記、待辦、行程、記帳、訂閱或帳戶',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜尋',
                            onPressed: () => setState(() => query = ''),
                            icon: const Icon(Icons.close),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (reverseLinks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '被 ${reverseLinks.length} 個項目引用',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              Expanded(
                child: candidates.isEmpty
                    ? const Center(child: Text('找不到可關聯的項目'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: candidates.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = candidates[index];
                          final selected = selectedKeys.contains(item.key);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            leading: Icon(_relatedItemIcon(item.type)),
                            title: Text(item.title),
                            subtitle: Text(
                              '${_relatedItemLabel(item.type)} · ${item.subtitle}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '開啟項目',
                                  onPressed: () => showRelatedItemDetails(
                                    context,
                                    store: store,
                                    link: item.link,
                                  ),
                                  icon: const Icon(Icons.open_in_new),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.add_circle_outline,
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ],
                            ),
                            selected: selected,
                            onTap: () => toggle(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RelatedItemDetailsPage extends StatelessWidget {
  const RelatedItemDetailsPage({super.key, required this.link});

  final RelatedItemLink link;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final item = store.describeRelatedItem(link);
    final outgoing = store.relatedItemsFrom(link);
    final incoming = store.reverseLinksTo(link);

    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: item?.title ?? '找不到項目',
          subtitle: item == null
              ? '這筆資料可能已被刪除'
              : '${_relatedItemLabel(item.type)} · ${item.subtitle}',
          leading: const PageBackButton(),
          child: item == null
              ? const Center(child: Text('無法開啟這筆關聯資料'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _RelatedSection(
                      title: '關聯項目',
                      emptyText: '沒有連結到其他項目',
                      items: outgoing,
                      store: store,
                    ),
                    const SizedBox(height: 16),
                    _RelatedSection(
                      title: '引用此項目',
                      emptyText: '目前沒有其他項目引用它',
                      items: incoming,
                      store: store,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.store,
  });

  final String title;
  final String emptyText;
  final List<RelatedItemDescriptor> items;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${items.length})',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(emptyText)
        else
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_relatedItemIcon(item.type)),
              title: Text(item.title),
              subtitle: Text(
                '${_relatedItemLabel(item.type)} · ${item.subtitle}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showRelatedItemDetails(
                context,
                store: store,
                link: item.link,
              ),
            ),
      ],
    );
  }
}

String _linkKey(RelatedItemLink link) => '${link.type.name}:${link.targetId}';

String _relatedItemLabel(RelatedItemType type) => switch (type) {
  RelatedItemType.note => '筆記',
  RelatedItemType.todo => '待辦',
  RelatedItemType.schedule => '行程',
  RelatedItemType.finance => '記帳',
  RelatedItemType.subscription => '訂閱',
  RelatedItemType.plan => '計畫',
  RelatedItemType.mindMap => '心智圖',
  RelatedItemType.lifeProject => '人生試算表',
  RelatedItemType.account => '帳戶',
};

IconData _relatedItemIcon(RelatedItemType type) => switch (type) {
  RelatedItemType.note => Icons.note_outlined,
  RelatedItemType.todo => Icons.check_box_outlined,
  RelatedItemType.schedule => Icons.event_outlined,
  RelatedItemType.finance => Icons.receipt_long_outlined,
  RelatedItemType.subscription => Icons.autorenew,
  RelatedItemType.plan => Icons.account_tree_outlined,
  RelatedItemType.mindMap => Icons.hub_outlined,
  RelatedItemType.lifeProject => Icons.stacked_bar_chart_outlined,
  RelatedItemType.account => Icons.account_balance_wallet_outlined,
};
