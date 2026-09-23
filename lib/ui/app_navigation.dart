part of '../main.dart';

class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    super.key,
    required this.onNavigate,
    required this.onOpenNotesLocation,
    required this.onOpenCalendarDailySchedule,
    required super.child,
  });

  final ValueChanged<int> onNavigate;
  final void Function(String folder, {bool showTrash}) onOpenNotesLocation;
  final ValueChanged<DateTime> onOpenCalendarDailySchedule;

  static AppNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppNavigationScope>();
  }

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) => false;
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.style = AppNavBarStyle.template6,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AppNavBarStyle style;

  static const items = [
    AppNavItem(
      label: '筆記',
      icon: Icons.sticky_note_2_outlined,
      selectedIcon: Icons.sticky_note_2,
    ),
    AppNavItem(
      label: '行程',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
    AppNavItem(
      label: '首頁',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AppNavItem(
      label: '記帳',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    AppNavItem(
      label: '設定',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      AppNavBarStyle.template6 => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xffe2e6f4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SizedBox(
              height: 92,
              child: Row(
                children: [
                  for (var index = 0; index < items.length; index++)
                    Expanded(
                      child: AppBottomNavigationItem(
                        item: items[index],
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    };
  }
}

class AppBottomNavigationItem extends StatelessWidget {
  const AppBottomNavigationItem({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inactiveColor = const Color(0xff596273);
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.fromLTRB(4, 10, 4, 9),
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          transform: Matrix4.translationValues(0, selected ? -10 : 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: selected ? 46 : 40,
                height: selected ? 46 : 38,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(selected ? 999 : 18),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 9),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? Colors.white : inactiveColor,
                  size: selected ? 27 : 23,
                ),
              ),
              SizedBox(height: selected ? 2 : 3),
              Text(
                item.label,
                style: TextStyle(
                  color: selected ? colorScheme.primary : inactiveColor,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

String appNavBarStyleLabel(AppNavBarStyle style) {
  return switch (style) {
    AppNavBarStyle.template6 => 'Template 6',
  };
}
