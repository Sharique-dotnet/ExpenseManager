import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../auth/auth.dart';
import 'expense.dart';
import 'expense_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) throw StateError('Expenses are only available when signed in');
  return ExpenseRepository(ref.watch(firestoreProvider), uid);
});

/// Today's local date. Re-checks every 30 s so the Today screen rolls over at
/// midnight and follows device timezone changes.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = dateOnly(DateTime.now());
      if (now != state) state = now;
    });
    ref.onDispose(timer.cancel);
    return dateOnly(DateTime.now());
  }
}

/// Expenses on one local date, newest first.
final dayExpensesProvider = StreamProvider.autoDispose.family<List<Expense>, DayKey>(
  (ref, day) => ref.watch(expenseRepositoryProvider).watchDays(day, day),
);

/// Total paise per day for the month containing the given date. One query per month.
final monthTotalsProvider = StreamProvider.autoDispose.family<Map<DayKey, int>, DateTime>((ref, month) {
  final (from, to) = monthRange(month);
  return ref.watch(expenseRepositoryProvider).watchDays(from, to).map(totalsByDay);
});
