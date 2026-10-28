import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth.dart';
import '../features/auth/auth_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/expenses/expense_form.dart';
import '../features/expenses/today_screen.dart';
import 'theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

class ExpenseApp extends ConsumerWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On sign-out or session expiry, drop any pushed screens and sheets.
    ref.listen(authStateProvider, (prev, next) {
      if (prev?.value != null && next.value == null) _navigatorKey.currentState?.popUntil((r) => r.isFirst);
    });

    return MaterialApp(
      title: 'Expense Manager',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(authStateProvider)) {
      AsyncData(value: final user?) => HomeShell(key: ValueKey(user.uid)),
      AsyncLoading() => const Scaffold(body: Center(child: CircularProgressIndicator())),
      _ => const AuthScreen(),
    };
  }
}

/// Notched bottom bar: Today | centre add button | Calendar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// Today's own messenger, so "Expense saved" floats above its total panel.
  final _todayMessenger = GlobalKey<ScaffoldMessengerState>();

  void _select(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back from Calendar returns to Today before leaving the app.
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        // Screens run behind the bar so the notch shows them rather than a gap.
        extendBody: true,
        body: IndexedStack(
          index: _tab,
          children: [
            TodayScreen(messengerKey: _todayMessenger),
            const CalendarScreen(),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add expense',
          onPressed: () => showExpenseForm(context, messenger: _tab == 0 ? _todayMessenger.currentState : null),
          child: const Icon(Icons.add_rounded),
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const AutomaticNotchedShape(
            RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card + 8))),
            CircleBorder(),
          ),
          notchMargin: Space.sm,
          height: 72,
          padding: EdgeInsets.zero,
          color: AppColors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          shadowColor: AppColors.ink.withValues(alpha: 0.25),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  label: 'Today',
                  icon: Icons.today_outlined,
                  selectedIcon: Icons.today_rounded,
                  selected: _tab == 0,
                  onTap: () => _select(0),
                ),
              ),
              const SizedBox(width: 96), // room for the add button
              Expanded(
                child: _NavItem(
                  label: 'Calendar',
                  icon: Icons.calendar_month_outlined,
                  selectedIcon: Icons.calendar_month_rounded,
                  selected: _tab == 1,
                  onTap: () => _select(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 26),
            const SizedBox(height: Space.xs),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
