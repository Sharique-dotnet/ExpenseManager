import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/dates.dart';
import '../auth/auth.dart';
import 'expense_providers.dart';
import 'expense_widgets.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.messengerKey});

  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final text = Theme.of(context).textTheme;

    return DayExpensesScaffold(
      day: dayKeyOf(today),
      totalLabel: 'Total spent today',
      messengerKey: messengerKey,
      addButtonInShell: true,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.sm, Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Wordmark(),
                const Spacer(),
                IconButton(
                  tooltip: 'Account',
                  onPressed: () => _showAccount(context, ref),
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text("Today's Expenses", style: text.headlineMedium),
            const SizedBox(height: Space.xs),
            Text(formatWeekdayDayMonth(today), style: text.bodyMedium!.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showAccount(BuildContext context, WidgetRef ref) {
    final auth = ref.read(firebaseAuthProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Signed in as', style: Theme.of(sheetContext).textTheme.bodySmall),
              const SizedBox(height: Space.xs),
              Text(auth.currentUser?.email ?? '', style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: Space.xl),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  auth.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
