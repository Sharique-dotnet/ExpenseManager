import 'dart:async';

import 'package:expense_manager/core/dates.dart';
import 'package:expense_manager/core/money.dart';
import 'package:expense_manager/features/expenses/expense.dart';
import 'package:expense_manager/features/expenses/expense_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense(String id, int paise, DateTime at) =>
    Expense(id: id, itemName: id, amountPaise: paise, occurredAt: at, localDate: dayKeyOf(at));

void main() {
  group('INR formatting', () {
    test('formats paise with two decimals and Indian grouping', () {
      expect(formatInr(0), '₹0.00');
      expect(formatInr(5), '₹0.05');
      expect(formatInr(2000), '₹20.00');
      expect(formatInr(35050), '₹350.50');
      expect(formatInr(12345678), '₹1,23,456.78');
      expect(formatInr(maxAmountPaise), '₹10,00,000.00');
      expect(formatInr(123456789012), '₹1,23,45,67,890.12');
    });

    test('compact labels for calendar cells', () {
      expect(formatInrCompact(12000), '₹120');
      expect(formatInrCompact(12050), '₹121');
      expect(formatInrCompact(99900), '₹999');
      expect(formatInrCompact(100000), '₹1k');
      expect(formatInrCompact(120000), '₹1.2k');
      expect(formatInrCompact(9996000), '₹1L'); // ₹99,960 would round to "100k"
      expect(formatInrCompact(25000000), '₹2.5L');
      expect(formatInrCompact(1000000000), '₹1Cr');
    });

    test('paise to editable input', () {
      expect(paiseToInput(35000), '350');
      expect(paiseToInput(35005), '350.05');
      expect(paiseToInput(35050), '350.50');
    });
  });

  group('amount parsing and validation', () {
    test('parses rupees into paise without floating point', () {
      expect(parsePaise('120'), 12000);
      expect(parsePaise('120.5'), 12050);
      expect(parsePaise('120.05'), 12005);
      expect(parsePaise('0.10'), 10);
      expect(parsePaise(' 1,250.75 '), 125075);
      expect(parsePaise('19.99'), 1999); // 19.99 * 100 is 1998.999… in floating point
    });

    test('rejects malformed input', () {
      for (final input in ['', 'abc', '-5', '12.345', '1.2.3', '.5', '1e3', '₹20']) {
        expect(parsePaise(input), isNull, reason: input);
      }
    });

    test('validateAmount enforces > 0 and the documented maximum', () {
      expect(validateAmount(''), isNotNull);
      expect(validateAmount('0'), isNotNull);
      expect(validateAmount('0.00'), isNotNull);
      expect(validateAmount('-1'), isNotNull);
      expect(validateAmount('1000000.01'), isNotNull);
      expect(validateAmount('0.01'), isNull);
      expect(validateAmount('1000000'), isNull);
    });

    test('validateItemName trims and limits length', () {
      expect(validateItemName(''), isNotNull);
      expect(validateItemName('   '), isNotNull);
      expect(validateItemName('  Tea  '), isNull);
      expect(validateItemName('x' * maxItemNameLength), isNull);
      expect(validateItemName('x' * (maxItemNameLength + 1)), isNotNull);
    });
  });

  group('payment type', () {
    test('reads stored keys and tolerates anything else', () {
      expect(PaymentType.fromStored('cash'), PaymentType.cash);
      expect(PaymentType.fromStored('upi'), PaymentType.upi);
      expect(PaymentType.fromStored('bank_transfer'), PaymentType.bankTransfer);
      for (final bad in [null, '', 'paypal', 'UPI', 'Bank Transfer', 42]) {
        expect(PaymentType.fromStored(bad), isNull, reason: '$bad');
      }
    });

    test('labels, with Not specified for legacy records', () {
      expect(paymentLabel(PaymentType.bankTransfer), 'Bank Transfer');
      expect(paymentLabel(null), 'Not specified');
      expect(validatePaymentType(null), isNotNull);
      expect(validatePaymentType(PaymentType.cash), isNull);
    });

    test('drafts always write a supported key', () {
      final draft = ExpenseDraft(
        itemName: 'Tea',
        amountPaise: 2000,
        occurredAt: DateTime(2026, 10, 28, 10),
        paymentType: PaymentType.bankTransfer,
      );
      expect(draft.toFields()['paymentType'], 'bank_transfer');
    });
  });

  group('totals, grouping and sorting', () {
    final today = DateTime(2026, 10, 28);
    final expenses = [
      _expense('tea', 2000, DateTime(2026, 10, 28, 10, 35)),
      _expense('lunch', 12000, DateTime(2026, 10, 28, 13, 15)),
      _expense('groceries', 35000, DateTime(2026, 10, 28, 18, 40)),
      _expense('bus', 1500, DateTime(2026, 10, 27, 23, 59)),
      _expense('milk', 3000, DateTime(2026, 10, 1, 0, 0)),
    ];

    test('daily total uses integer paise', () {
      final todays = expenses.where((e) => e.localDate == dayKeyOf(today));
      expect(formatInr(totalPaise(todays)), '₹490.00');
      expect(totalPaise(const []), 0);
    });

    test('groups by local calendar date', () {
      expect(totalsByDay(expenses), {20261028: 49000, 20261027: 1500, 20261001: 3000});
      expect(totalsByDay(const []), isEmpty);
    });

    test('sorts newest first', () {
      expect(sortedNewestFirst(expenses).map((e) => e.id), ['groceries', 'lunch', 'tea', 'bus', 'milk']);
    });

    test('same-minute ties go to the most recently added', () {
      final at = DateTime(2026, 10, 28, 18, 36);
      Expense make(String id, DateTime? createdAt) =>
          Expense(id: id, itemName: id, amountPaise: 1, occurredAt: at, localDate: 20261028, createdAt: createdAt);
      final sorted = sortedNewestFirst([
        make('a-first', DateTime(2026, 10, 28, 18, 36, 5)),
        make('z-pending', null),
        make('b-second', DateTime(2026, 10, 28, 18, 36, 40)),
      ]);
      expect(sorted.map((e) => e.id), ['z-pending', 'b-second', 'a-first']);
    });

    test('groups by the stored localDate, not the instant', () {
      // Saved as 28 Oct in one timezone; must stay on 28 Oct wherever it is viewed.
      final e = Expense(
        id: 'x',
        itemName: 'x',
        amountPaise: 100,
        occurredAt: DateTime.utc(2026, 10, 27, 20),
        localDate: 20261028,
      );
      expect(totalsByDay([e]).keys, [20261028]);
    });
  });

  group('dates', () {
    test('day keys round-trip', () {
      expect(dayKeyOf(DateTime(2026, 10, 28, 23, 59)), 20261028);
      expect(dateOfKey(20240229), DateTime(2024, 2, 29));
      expect(dateOfKey(dayKeyOf(DateTime(2026, 1, 1))), DateTime(2026, 1, 1));
    });

    test('month lengths and leap years', () {
      expect(daysInMonth(DateTime(2024, 2)), 29);
      expect(daysInMonth(DateTime(2026, 2)), 28);
      expect(daysInMonth(DateTime(2000, 2)), 29);
      expect(daysInMonth(DateTime(2100, 2)), 28);
      expect(daysInMonth(DateTime(2026, 4)), 30);
      expect(daysInMonth(DateTime(2026, 12)), 31);
    });

    test('month ranges and boundaries', () {
      expect(monthRange(DateTime(2024, 2, 15)), (20240201, 20240229));
      expect(monthRange(DateTime(2026, 12)), (20261201, 20261231));
      expect(DateTime(2026, 12 + 1), DateTime(2027, 1)); // next-month navigation
      expect(DateTime(2026, 1 - 1), DateTime(2025, 12)); // previous-month navigation
    });

    test('form date labels stay short', () {
      final today = DateTime(2026, 10, 28);
      expect(formatPickerDate(today, today), 'Today');
      expect(formatPickerDate(DateTime(2026, 10, 27), today), 'Yesterday');
      expect(formatPickerDate(DateTime(2026, 10, 26), today), 'Mon, 26 Oct');
      expect(formatPickerDate(DateTime(2025, 12, 31), today), '31 Dec 2025');
      expect(formatPickerDate(DateTime(2027, 1, 1), DateTime(2027, 1, 2)), 'Yesterday');
    });

    test('Monday-first leading blanks', () {
      expect(leadingBlanks(DateTime(2026, 10)), 3); // 1 Oct 2026 is a Thursday
      expect(leadingBlanks(DateTime(2026, 6)), 0); // Monday
      expect(leadingBlanks(DateTime(2026, 11)), 6); // Sunday
    });

    group('validateOccurredAt', () {
      final now = DateTime(2026, 10, 28, 14, 30);

      test('accepts now and earlier today', () {
        expect(validateOccurredAt(now, now), isNull);
        expect(validateOccurredAt(DateTime(2026, 10, 28, 0, 0), now), isNull);
      });

      test('accepts any time on a past date', () {
        expect(validateOccurredAt(DateTime(2026, 10, 27, 23, 59), now), isNull);
        expect(validateOccurredAt(DateTime(2024, 2, 29, 23, 59), now), isNull);
      });

      test('rejects a later time today', () {
        expect(validateOccurredAt(DateTime(2026, 10, 28, 14, 31), now), isNotNull);
      });

      test('rejects future dates', () {
        expect(validateOccurredAt(DateTime(2026, 10, 29, 0, 0), now), isNotNull);
        expect(validateOccurredAt(DateTime(2027, 1, 1), now), isNotNull);
      });
    });
  });

  group('waitForServer', () {
    void noLateError(Object _) => fail('unexpected late error');

    test('true when the server acknowledges in time', () async {
      expect(await waitForServer(Future.value(), onLateError: noLateError), isTrue);
    });

    test('false when the write is only queued locally', () async {
      final pending = Completer<void>();
      expect(
        await waitForServer(pending.future, onLateError: noLateError, timeout: const Duration(milliseconds: 10)),
        isFalse,
      );
    });

    test('rethrows errors that arrive before the timeout', () {
      expect(waitForServer(Future.error(StateError('denied')), onLateError: noLateError), throwsStateError);
    });

    test('reports errors that arrive after the timeout', () async {
      final pending = Completer<void>();
      Object? late;
      await waitForServer(pending.future, onLateError: (e) => late = e, timeout: const Duration(milliseconds: 10));
      pending.completeError(StateError('rejected on sync'));
      await Future<void>.delayed(Duration.zero);
      expect(late, isA<StateError>());
    });
  });
}
