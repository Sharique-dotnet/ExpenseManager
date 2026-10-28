import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import 'expense.dart';
import 'expense_form.dart';
import 'expense_providers.dart';
import 'expense_repository.dart';

/// List + pinned total for one local date. Shared by Today and Day Details.
class DayExpensesScaffold extends ConsumerWidget {
  const DayExpensesScaffold({
    super.key,
    required this.day,
    required this.header,
    required this.totalLabel,
    this.emptyTitle = 'No expenses yet.',
    this.messengerKey,
    this.addButtonInShell = false,
  });

  final DayKey day;
  final Widget header;
  final String totalLabel;
  final String emptyTitle;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  /// True on Today, where the add button is docked in the shell's bar below
  /// (and pokes up into the total panel) instead of floating over the list.
  final bool addButtonInShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(dayExpensesProvider(day));
    final list = expenses.value;

    // Own messenger so snackbars float above this screen's total panel,
    // not above the shell's navigation bar (where they'd cover the total).
    return ScaffoldMessenger(
      key: messengerKey,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: list == null
                    ? expenses.hasError
                          ? ErrorState(
                              message: "Couldn't load expenses.",
                              details: describeError(expenses.error!),
                              onRetry: () => ref.invalidate(dayExpensesProvider(day)),
                            )
                          : const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                    ? EmptyState(title: emptyTitle)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          Space.page,
                          Space.sm,
                          Space.page,
                          addButtonInShell ? Space.lg : 96,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                        itemBuilder: (_, i) => ExpenseTile(expense: list[i]),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: addButtonInShell
            ? null
            : Builder(
                builder: (context) => FloatingActionButton(
                  tooltip: 'Add expense',
                  onPressed: () => showExpenseForm(context, initialDate: dateOfKey(day)),
                  child: const Icon(Icons.add_rounded),
                ),
              ),
        bottomNavigationBar: DailyTotalPanel(
          label: totalLabel,
          count: list?.length ?? 0,
          totalPaise: list == null ? null : totalPaise(list),
          // Half the docked button plus its notch margin.
          bottomClearance: addButtonInShell ? 40 : 0,
        ),
      ),
    );
  }
}

class ExpenseTile extends ConsumerWidget {
  const ExpenseTile({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final initial = expense.itemName.characters.first.toUpperCase();

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showExpenseForm(context, existing: expense),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.xs, Space.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(Radii.input)),
                child: Text(initial, style: text.titleMedium!.copyWith(color: AppColors.moss)),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.itemName,
                      style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${formatTime(expense.occurredAt)} · ${paymentLabel(expense.paymentType)}',
                            style: text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (expense.pendingSync) ...[
                          const SizedBox(width: Space.sm),
                          const Icon(Icons.cloud_upload_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Text('Syncing', style: text.bodySmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(formatInr(expense.amountPaise), style: text.titleMedium),
              PopupMenuButton<String>(
                tooltip: 'Options for ${expense.itemName}',
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                onSelected: (action) => action == 'edit'
                    ? showExpenseForm(context, existing: expense)
                    : confirmAndDelete(context, ref, expense),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: AppColors.coralText)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> confirmAndDelete(BuildContext context, WidgetRef ref, Expense expense) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete expense?'),
      content: Text('${expense.itemName} · ${formatInr(expense.amountPaise)} will be removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.coralText),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    final synced = await waitForServer(
      ref.read(expenseRepositoryProvider).delete(expense.id),
      onLateError: (_) {
        if (messenger.mounted) messenger.showSnackBar(const SnackBar(content: Text("A deletion couldn't be synced.")));
      },
    );
    messenger.showSnackBar(
      SnackBar(content: Text(synced ? 'Expense deleted' : 'Deleted on this device. Will sync when online.')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text("Couldn't delete. ${describeError(e)}")));
  }
}

/// Pinned bottom summary: count, label and the exact INR total.
class DailyTotalPanel extends StatelessWidget {
  const DailyTotalPanel({
    super.key,
    required this.label,
    required this.count,
    required this.totalPaise,
    this.bottomClearance = 0,
  });

  final String label;
  final int count;

  /// Extra space below the content for a button docked over the panel's bottom edge.
  final double bottomClearance;

  /// Null while loading.
  final int? totalPaise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card + 8)),
      ),
      padding: EdgeInsets.fromLTRB(Space.xl, Space.lg + 2, Space.xl, Space.lg + 2 + bottomClearance),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w700, color: AppColors.mossDark),
                  ),
                ),
                const SizedBox(width: Space.md),
                Text(
                  count == 1 ? '1 expense' : '$count expenses',
                  style: text.bodySmall!.copyWith(color: AppColors.mossDark),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            // Scales down rather than overflowing for very large totals.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                totalPaise == null ? '—' : formatInr(totalPaise!),
                key: const Key('daily-total'),
                style: text.headlineLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.title = 'No expenses yet.'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Scrolls rather than overflowing when the area shrinks (e.g. keyboard open).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(Radii.card + 4)),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.moss, size: 30),
            ),
            const SizedBox(height: Space.lg),
            Text(title, style: text.titleLarge),
            const SizedBox(height: Space.xs),
            Text(
              'Add your first expense to get started.',
              style: text.bodyMedium!.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry, this.details});

  final String message;
  final String? details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.coral, size: 36),
            const SizedBox(height: Space.md),
            Text(message, style: text.titleLarge, textAlign: TextAlign.center),
            if (details != null) ...[
              const SizedBox(height: Space.xs),
              Text(details!, style: text.bodySmall, textAlign: TextAlign.center),
            ],
            const SizedBox(height: Space.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Short, user-facing text for Firestore failures.
String describeError(Object error) {
  return switch (error is FirebaseException ? error.code : null) {
    'permission-denied' => 'Permission denied. Check the date and amount, or sign in again.',
    'unauthenticated' => 'Your session expired. Please sign in again.',
    'unavailable' => 'You appear to be offline.',
    'not-found' => 'This expense no longer exists.',
    _ => 'Please try again.',
  };
}
