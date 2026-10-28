import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth.dart';
import '../features/auth/auth_screen.dart';
import '../features/calendar/calendar_screen.dart';
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

/// Bottom navigation between Today and Calendar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back from Calendar returns to Today before leaving the app.
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _tab, children: const [TodayScreen(), CalendarScreen()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
            ),
          ],
        ),
      ),
    );
  }
}
