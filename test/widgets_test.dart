import 'dart:async';

import 'package:expense_manager/app/app.dart';
import 'package:expense_manager/app/theme.dart';
import 'package:expense_manager/core/dates.dart';
import 'package:expense_manager/features/calendar/calendar_screen.dart';
import 'package:expense_manager/features/expenses/expense.dart';
import 'package:expense_manager/features/expenses/expense_providers.dart';
import 'package:expense_manager/features/expenses/expense_repository.dart';
import 'package:expense_manager/features/expenses/today_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ExpenseRepository repo;
  final today = dateOnly(DateTime.now());
  // Early-morning times so they're always "today" and never after now's date.
  DateTime todayAt(int minute) => DateTime(today.year, today.month, today.day, 0, minute);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ExpenseRepository(db, 'u1');
  });

  Future<void> seed(String name, int paise, DateTime at, {PaymentType type = PaymentType.cash}) =>
      repo.create(repo.newId(), ExpenseDraft(itemName: name, amountPaise: paise, occurredAt: at, paymentType: type));

  /// A doc as stored before payment types existed (or with a bad value), bypassing the app's writer.
  Future<void> seedRaw(String id, String name, int paise, DateTime at, {Object? paymentType}) =>
      db.collection('users').doc('u1').collection('expenses').doc(id).set({
        'itemName': name,
        'amountPaise': paise,
        'occurredAt': Timestamp.fromDate(at),
        'localDate': dayKeyOf(at),
        'paymentType': ?paymentType,
      });

  Future<void> choosePayment(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<PaymentType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, Widget screen, {List<dynamic> overrides = const []}) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo), ...overrides],
        child: MaterialApp(
          theme: buildTheme(),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Today screen', () {
    testWidgets('empty state shows ₹0.00', (tester) async {
      await pump(tester, const TodayScreen());
      expect(find.text("Today's Expenses"), findsOneWidget);
      expect(find.text(formatWeekdayDayMonth(today)), findsOneWidget);
      expect(find.text('No expenses yet.'), findsOneWidget);
      expect(find.text('0 expenses'), findsOneWidget);
      expect(find.byKey(const Key('daily-total')), findsOneWidget);
      expect(find.text('₹0.00'), findsOneWidget);
    });

    testWidgets('bottom bar: centre add button and tab switching', (tester) async {
      await pump(tester, const HomeShell());
      expect(find.byTooltip('Add expense'), findsOneWidget);
      expect(find.text("Today's Expenses"), findsOneWidget);

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Expense Calendar'), findsOneWidget);

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text("Today's Expenses"), findsOneWidget);
    });

    testWidgets("lists only today's expenses, newest first, with the total", (tester) async {
      await seed('Tea', 2000, todayAt(1));
      await seed('Lunch', 12000, todayAt(2));
      await seed('Groceries', 35000, todayAt(3));
      await seed('Yesterday dinner', 99900, today.subtract(const Duration(hours: 2)));
      await pump(tester, const TodayScreen());

      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Yesterday dinner'), findsNothing);
      expect(find.text('3 expenses'), findsOneWidget);
      expect(find.text('₹490.00'), findsOneWidget);
      expect(find.text('Total spent today'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Groceries')).dy, lessThan(tester.getTopLeft(find.text('Tea')).dy));
    });

    testWidgets('loading state', (tester) async {
      final never = StreamController<List<Expense>>();
      addTearDown(never.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dayExpensesProvider.overrideWith((ref, day) => never.stream)],
          child: MaterialApp(theme: buildTheme(), home: const TodayScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('error state offers retry', (tester) async {
      await pump(
        tester,
        const TodayScreen(),
        overrides: [
          dayExpensesProvider.overrideWith(
            (ref, day) => Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')),
          ),
        ],
      );
      expect(find.text("Couldn't load expenses."), findsOneWidget);
      expect(find.text('You appear to be offline.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Add expense form', () {
    testWidgets('opens and cancels', (tester) async {
      await pump(tester, const HomeShell());
      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.widgetWithText(InputDecorator, 'Today'), findsOneWidget); // date defaults to today

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add expense'), findsNothing);
    });

    testWidgets('requires item and amount', (tester) async {
      await pump(tester, const HomeShell());
      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();
      expect(find.text('Enter what you spent on'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(find.text('Select a payment type'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '0');
      await tester.pumpAndSettle();
      expect(find.text('Amount must be more than ₹0'), findsOneWidget);
    });

    testWidgets('primary flow: add → see it and the updated total', (tester) async {
      await seed('Tea', 2000, todayAt(1));
      await pump(tester, const HomeShell());
      expect(find.text('₹20.00'), findsNWidgets(2)); // row + total

      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Item'), '  Lunch ');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '120.50');
      await choosePayment(tester, 'UPI');
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();

      expect(find.text('Add expense'), findsNothing);
      expect(find.text('Expense saved'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('₹120.50'), findsOneWidget);
      expect(find.textContaining('· UPI'), findsOneWidget);
      expect(find.text('2 expenses'), findsOneWidget);
      expect(find.text('₹140.50'), findsOneWidget);
    });

    testWidgets('edit and delete update the total', (tester) async {
      await seed('Tea', 2000, todayAt(1));
      await seed('Lunch', 12000, todayAt(2));
      await pump(tester, const HomeShell());

      await tester.tap(find.text('Tea'));
      await tester.pumpAndSettle();
      expect(find.text('Edit expense'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '25');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('₹145.00'), findsOneWidget);

      await tester.tap(find.byTooltip('Options for Lunch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete expense?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Lunch'), findsNothing);
      expect(find.text('1 expense'), findsOneWidget);
      expect(find.text('₹25.00'), findsNWidgets(2));
    });
  });

  group('Payment type', () {
    testWidgets('legacy and unknown values show Not specified; totals unchanged', (tester) async {
      await seedRaw('legacy', 'Lunch', 12000, todayAt(1));
      await seedRaw('odd', 'Snacks', 3000, todayAt(2), paymentType: 'paypal');
      await seed('Groceries', 35000, todayAt(3), type: PaymentType.upi);
      await pump(tester, const TodayScreen());

      expect(find.textContaining('· Not specified'), findsNWidgets(2));
      expect(find.textContaining('· UPI'), findsOneWidget);
      expect(find.text('₹500.00'), findsOneWidget);
      expect(find.text('3 expenses'), findsOneWidget);
    });

    testWidgets('editing a legacy record requires a choice; cancel leaves it untouched', (tester) async {
      await seedRaw('legacy', 'Lunch', 12000, todayAt(1));
      final doc = db.collection('users').doc('u1').collection('expenses').doc('legacy');
      await pump(tester, const HomeShell());

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      expect(find.text('Select'), findsOneWidget); // no type pre-selected
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Select a payment type'), findsOneWidget);
      expect(find.text('Edit expense'), findsOneWidget); // still open, nothing saved

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await doc.get()).data()!.containsKey('paymentType'), isFalse);

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      await choosePayment(tester, 'Cash');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect((await doc.get()).data()!['paymentType'], 'cash');
      expect(find.textContaining('· Cash'), findsOneWidget);
    });
  });

  group('Calendar', () {
    testWidgets('shows daily totals and opens Day Details', (tester) async {
      await seed('Tea', 2000, todayAt(1));
      await seed('Groceries', 35000, todayAt(2));
      await pump(tester, const CalendarScreen());

      expect(find.text('Expense Calendar'), findsOneWidget);
      expect(find.text(formatMonthYear(today)), findsOneWidget);
      expect(find.text('₹370'), findsOneWidget);

      await tester.tap(find.text('₹370'));
      await tester.pumpAndSettle();

      expect(find.text(formatFullDate(today)), findsOneWidget);
      expect(find.text('Daily expense summary'), findsOneWidget);
      expect(find.text('Total spent on this date'), findsOneWidget);
      expect(find.text('₹370.00'), findsOneWidget);
      expect(find.text('2 expenses'), findsOneWidget);
    });

    testWidgets('month navigation and empty Day Details', (tester) async {
      await pump(tester, const CalendarScreen());
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      final previous = DateTime(today.year, today.month - 1);
      expect(find.text(formatMonthYear(previous)), findsOneWidget);
      expect(find.text('No expenses in ${formatMonthName(previous)}'), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(find.text(formatFullDate(DateTime(previous.year, previous.month, 15))), findsOneWidget);
      expect(find.text('No expenses on this date.'), findsOneWidget);
      expect(find.text('₹0.00'), findsOneWidget);
    });
  });
}
