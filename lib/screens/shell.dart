import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'graph/month_screen.dart';
import 'more/more_screen.dart';
import 'prs/hall_of_fame_screen.dart';
import 'today/today_screen.dart';
import 'workout/workout_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshReminders();
  }

  /// Re-plans the next week of gym-window reminders, suppressing today's if
  /// a workout has already been started.
  Future<void> _refreshReminders() async {
    final windows = await ref.read(gymWindowDaoProvider).all();
    if (windows.isEmpty) return;
    final workedOut = await ref.read(statsDaoProvider).workedOutToday();
    await ref
        .read(notificationServiceProvider)
        .rescheduleAll(windows, workedOutToday: workedOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    const screens = [
      TodayScreen(),
      WorkoutScreen(),
      MonthScreen(),
      HallOfFameScreen(),
      MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.ink, width: 2)),
        ),
        child: NavigationBar(
          height: 72, // big touch targets throughout
          backgroundColor: Colors.transparent,
          indicatorColor: c.accent.withValues(alpha: 0.18),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.restaurant_outlined),
                selectedIcon: Icon(Icons.restaurant),
                label: 'Today'),
            NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Lift'),
            NavigationDestination(
                icon: Icon(Icons.insert_chart_outlined),
                selectedIcon: Icon(Icons.insert_chart),
                label: 'Month'),
            NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'PRs'),
            NavigationDestination(
                icon: Icon(Icons.menu_outlined),
                selectedIcon: Icon(Icons.menu),
                label: 'More'),
          ],
        ),
      ),
    );
  }
}
