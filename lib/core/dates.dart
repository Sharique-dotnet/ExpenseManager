import 'package:intl/intl.dart';

/// A local calendar date encoded as yyyymmdd (e.g. 20261028).
///
/// Expenses store the date the user picked as this key, so an expense never
/// moves to a different day if the device timezone later changes.
typedef DayKey = int;

DayKey dayKeyOf(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime dateOfKey(DayKey key) => DateTime(key ~/ 10000, key ~/ 100 % 100, key % 100);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month);

/// Handles leap years and month lengths via DateTime's day-0 normalisation.
int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// First and last day keys of [month], for range queries.
(DayKey, DayKey) monthRange(DateTime month) =>
    (dayKeyOf(firstOfMonth(month)), dayKeyOf(DateTime(month.year, month.month, daysInMonth(month))));

/// Blank cells before day 1 in a Monday-first grid.
int leadingBlanks(DateTime month) => firstOfMonth(month).weekday - DateTime.monday;

/// Combines a date with an hour/minute, dropping seconds.
DateTime combine(DateTime date, int hour, int minute) => DateTime(date.year, date.month, date.day, hour, minute);

/// Null when [occurredAt] is acceptable: today or earlier, and not later than [now].
String? validateOccurredAt(DateTime occurredAt, DateTime now) {
  if (dateOnly(occurredAt).isAfter(dateOnly(now))) return "Date can't be in the future";
  if (occurredAt.isAfter(now)) return "Time can't be later than now";
  return null;
}

final _weekdayDayMonth = DateFormat('EEEE, d MMMM');
final _fullDate = DateFormat('EEEE, d MMMM y');
final _monthYear = DateFormat('MMMM y');
final _month = DateFormat('MMMM');
final _weekdayDayShortMonth = DateFormat('EEE, d MMM');
final _dayShortMonthYear = DateFormat('d MMM y');
final _time = DateFormat('h:mm a');

String formatWeekdayDayMonth(DateTime d) => _weekdayDayMonth.format(d); // Wednesday, 28 October
String formatFullDate(DateTime d) => _fullDate.format(d); // Wednesday, 28 October 2026
String formatMonthYear(DateTime d) => _monthYear.format(d); // October 2026
String formatMonthName(DateTime d) => _month.format(d); // October
String formatTime(DateTime d) => _time.format(d); // 10:35 AM

/// Short label for the form's date field: Today, Yesterday, Mon, 26 Oct, or 26 Oct 2025.
String formatPickerDate(DateTime date, DateTime today) {
  if (date == today) return 'Today';
  if (date == DateTime(today.year, today.month, today.day - 1)) return 'Yesterday';
  return date.year == today.year ? _weekdayDayShortMonth.format(date) : _dayShortMonthYear.format(date);
}
