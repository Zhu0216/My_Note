import 'package:flutter/material.dart';

import '../../data/my_note_data.dart';
import '../../ui/app_store_scope.dart';
import '../../ui/basic_display.dart';
import '../../ui/calendar_components.dart';
import '../../ui/finance_charts.dart';
import '../../ui/formatters.dart';
import '../../ui/shared_components.dart';

class FinanceFeatureActions {
  const FinanceFeatureActions({
    required this.editEntry,
    required this.manageSubscriptions,
    required this.editSubscription,
    required this.editSavingsAccount,
    required this.showSavingsAccountActions,
    required this.editBudget,
  });

  final Future<void> Function(BuildContext context, {FinanceEntry? entry})
  editEntry;
  final Future<void> Function(BuildContext context) manageSubscriptions;
  final Future<void> Function(
    BuildContext context, {
    SubscriptionItem? subscription,
  })
  editSubscription;
  final Future<void> Function(
    BuildContext context, {
    SavingsAccount? account,
    bool editName,
  })
  editSavingsAccount;
  final Future<void> Function(BuildContext context, SavingsAccount account)
  showSavingsAccountActions;
  final Future<void> Function(BuildContext context) editBudget;
}

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.actions});

  final FinanceFeatureActions actions;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool showSubscriptions = false;
  bool showCashFlowAmounts = false;
  bool showSavingsAccountAmounts = false;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final grouped = groupExpensesByCategory(store.financeEntries);
    final incomeGrouped = groupIncomeByAccount(store.financeEntries);
    final budgetRatio = store.monthlyBudget == 0
        ? 0.0
        : (store.monthlyExpense / store.monthlyBudget).clamp(0.0, 1.3);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: AddBubbleButton(
        tooltip: '新增記帳',
        onPressed: () => widget.actions.editEntry(context),
        heroTag: 'finance-add',
      ),
      body: AppPage(
        title: '記帳',
        subtitle: '收入、支出、預算與訂閱管理',
        actions: [
          IconButton(
            tooltip: '近期紀錄',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    FinanceHistoryPage(actions: widget.actions),
              ),
            ),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: '訂閱管理',
            onPressed: () => widget.actions.manageSubscriptions(context),
            icon: const Icon(Icons.subscriptions),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            SectionHeader(
              title: '金流',
              trailing: IconButton(
                tooltip: showCashFlowAmounts ? '隱藏金額' : '顯示金額',
                onPressed: () =>
                    setState(() => showCashFlowAmounts = !showCashFlowAmounts),
                icon: Icon(
                  showCashFlowAmounts
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            FinanceMetricRow(
              items: [
                FinanceMetricInfo(
                  id: 'savings',
                  title: '存餘',
                  value: currency(store.savingsTotal),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xff4568b2),
                ),
                FinanceMetricInfo(
                  id: 'income',
                  title: '本月收入',
                  value: currency(store.monthlyIncome),
                  icon: Icons.trending_up,
                  color: const Color(0xff34785f),
                ),
                FinanceMetricInfo(
                  id: 'expense',
                  title: '本月支出',
                  value: currency(store.monthlyExpense),
                  icon: Icons.trending_down,
                  color: const Color(0xffb5533d),
                ),
              ],
              visible: showCashFlowAmounts,
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '存餘帳戶',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: showSavingsAccountAmounts ? '隱藏帳戶金額' : '顯示帳戶金額',
                    onPressed: () => setState(
                      () => showSavingsAccountAmounts =
                          !showSavingsAccountAmounts,
                    ),
                    icon: Icon(
                      showSavingsAccountAmounts
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: '新增帳戶',
                    onPressed: () => widget.actions.editSavingsAccount(context),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            if (store.savingsAccounts.isEmpty)
              const InfoCard(
                child: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  text: '尚無存餘帳戶',
                ),
              )
            else
              HomeTileWrap(
                children: [
                  for (final account in store.savingsAccounts)
                    SizedBox(
                      width: homeGridTileWidth(context),
                      child: SavingsAccountCard(
                        account: account,
                        visible: showSavingsAccountAmounts,
                        onLongPress: () => widget.actions
                            .showSavingsAccountActions(context, account),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '月預算提醒',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text('預算: ${currency(store.monthlyBudget)}'),
                            Text('花費: ${currency(store.monthlyExpense)}'),
                            Text(
                              '剩餘: ${currency(store.monthlyBudget - store.monthlyExpense)}',
                              style: TextStyle(
                                color:
                                    store.monthlyBudget >= store.monthlyExpense
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatPercent(budgetRatio),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => widget.actions.editBudget(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('調整預算'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '支出分類',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => FinanceTimelinePage(
                      type: EntryType.expense,
                      actions: widget.actions,
                    ),
                  ),
                ),
                child: const Text('查看'),
              ),
            ),
            InfoCard(
              child: grouped.isEmpty
                  ? const EmptyState(
                      icon: Icons.pie_chart_outline,
                      text: '尚無支出資料',
                    )
                  : Column(children: [ExpensePieChart(grouped: grouped)]),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '收入分類',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => FinanceTimelinePage(
                      type: EntryType.income,
                      actions: widget.actions,
                    ),
                  ),
                ),
                child: const Text('查看'),
              ),
            ),
            InfoCard(
              child: incomeGrouped.isEmpty
                  ? const EmptyState(icon: Icons.bar_chart, text: '尚無收入資料')
                  : IncomeAccountBarChart(grouped: incomeGrouped),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: '訂閱管理',
              trailing: Switch(
                value: showSubscriptions,
                onChanged: (value) => setState(() => showSubscriptions = value),
              ),
            ),
            if (showSubscriptions)
              InfoCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('每月訂閱總額'),
                      subtitle: const Text('依月費與年費換算估計'),
                      trailing: Text(
                        currency(store.monthlySubscriptionTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    for (final sub in store.upcomingSubscriptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SwipeDeleteTile(
                          itemKey: 'finance-subscription-${sub.id}',
                          confirmTitle: '刪除訂閱？',
                          confirmMessage: '這筆訂閱會從列表移除。',
                          onDelete: () => store.deleteSubscription(sub),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.autorenew),
                            title: Text(sub.name),
                            subtitle: Text(
                              '${formatDate(sub.nextPaymentDate)}  ${sub.paymentMethod}',
                            ),
                            trailing: Text(currency(sub.amount)),
                            onTap: () => widget.actions.editSubscription(
                              context,
                              subscription: sub,
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () =>
                            widget.actions.editSubscription(context),
                        icon: const Icon(Icons.add),
                        label: const Text('新增訂閱'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FinanceHistoryPage extends StatelessWidget {
  const FinanceHistoryPage({super.key, required this.actions});

  final FinanceFeatureActions actions;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final entries = store.financeEntries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: '近期紀錄',
          subtitle: '依日期排序的收入與支出',
          leading: const PageBackButton(),
          child: entries.isEmpty
              ? const EmptyState(icon: Icons.history, text: '目前沒有記帳紀錄')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final item in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FinanceTile(
                          entry: item,
                          onTap: () => actions.editEntry(context, entry: item),
                          onDelete: () => store.deleteFinanceEntry(item),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class FinanceTimelinePage extends StatelessWidget {
  const FinanceTimelinePage({
    super.key,
    required this.type,
    required this.actions,
  });

  final EntryType type;
  final FinanceFeatureActions actions;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final entries =
        store.financeEntries.where((entry) => entry.type == type).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final groups = groupFinanceEntriesByDate(entries);
    final isIncome = type == EntryType.income;

    return Scaffold(
      body: SafeArea(
        child: AppPage(
          title: isIncome ? '收入時間軸' : '支出時間軸',
          subtitle: isIncome ? '依日期查看收入紀錄' : '依日期查看支出紀錄',
          leading: const PageBackButton(),
          child: entries.isEmpty
              ? EmptyState(
                  icon: isIncome ? Icons.trending_up : Icons.trending_down,
                  text: isIncome ? '目前沒有收入紀錄' : '目前沒有支出紀錄',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final group in groups.entries) ...[
                      FinanceTimelineDateHeader(date: group.key),
                      for (final item in group.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FinanceTile(
                            entry: item,
                            onTap: () =>
                                actions.editEntry(context, entry: item),
                            onDelete: () => store.deleteFinanceEntry(item),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class FinanceTimelineDateHeader extends StatelessWidget {
  const FinanceTimelineDateHeader({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 17),
          const SizedBox(width: 8),
          Text(
            formatDate(date),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xff465064),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xffdfe5f4))),
        ],
      ),
    );
  }
}

class FinanceMetricInfo {
  const FinanceMetricInfo({
    required this.id,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class FinanceMetricRow extends StatelessWidget {
  const FinanceMetricRow({
    super.key,
    required this.items,
    required this.visible,
  });

  final List<FinanceMetricInfo> items;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(
              child: FinanceMetricCell(item: items[index], visible: visible),
            ),
            if (index != items.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class FinanceMetricCell extends StatelessWidget {
  const FinanceMetricCell({
    super.key,
    required this.item,
    required this.visible,
  });

  final FinanceMetricInfo item;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(item.icon, color: item.color, size: 22),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            visible ? item.value : '*****',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class SavingsAccountCard extends StatelessWidget {
  const SavingsAccountCard({
    super.key,
    required this.account,
    required this.visible,
    required this.onLongPress,
  });

  final SavingsAccount account;
  final bool visible;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                visible ? currency(account.amount) : '*****',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, double> groupExpensesByCategory(List<FinanceEntry> entries) {
  final now = DateTime.now();
  final result = <String, double>{};
  for (final entry in entries) {
    if (entry.type != EntryType.expense ||
        entry.date.year != now.year ||
        entry.date.month != now.month) {
      continue;
    }
    result.update(
      entry.category,
      (value) => value + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }
  return result;
}

Map<String, double> groupIncomeByAccount(List<FinanceEntry> entries) {
  final now = DateTime.now();
  final result = <String, double>{};
  for (final entry in entries) {
    if (entry.type != EntryType.income ||
        entry.date.year != now.year ||
        entry.date.month != now.month) {
      continue;
    }
    final account = entry.account.trim().isEmpty ? '未指定帳戶' : entry.account;
    result.update(
      account,
      (value) => value + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }
  return result;
}

Map<DateTime, List<FinanceEntry>> groupFinanceEntriesByDate(
  List<FinanceEntry> entries,
) {
  final result = <DateTime, List<FinanceEntry>>{};
  for (final entry in entries) {
    final key = DateTime(entry.date.year, entry.date.month, entry.date.day);
    result.putIfAbsent(key, () => <FinanceEntry>[]).add(entry);
  }
  return result;
}
