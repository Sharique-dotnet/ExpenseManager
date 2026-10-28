import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../expenses/day_details_screen.dart';
import '../expenses/expense_providers.dart';
import '../expenses/expense_widgets.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = firstOfMonth(ref.read(todayProvider));
  DayKey? _selected;

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _open(DateTime date) {
    setState(() => _selected = dayKeyOf(date));
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DayDetailsScreen(day: dayKeyOf(date))));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final totalsAsync = ref.watch(monthTotalsProvider(_month));
    final totals = totalsAsync.value ?? const <DayKey, int>{};
    final isCurrentMonth = _month == firstOfMonth(today);
    final monthName = formatMonthName(_month);
    final monthTotal = totals.values.fold(0, (a, b) => a + b);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xl + 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
            child: Row(
              children: [
                Expanded(child: Text('Expense Calendar', style: text.headlineMedium)),
                if (!isCurrentMonth)
                  ActionChip(
                    label: const Text('This month'),
                    onPressed: () => setState(() => _month = firstOfMonth(today)),
                    backgroundColor: AppColors.mint,
                    side: BorderSide.none,
                    labelStyle: text.labelMedium!.copyWith(color: AppColors.mossDark, fontSize: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(formatMonthYear(_month), style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      totalsAsync.isLoading && totalsAsync.value == null
                          ? 'Loading…'
                          : monthTotal == 0
                          ? 'No expenses in $monthName'
                          : '${formatInr(monthTotal)} spent in $monthName',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: text.labelMedium!.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (totalsAsync.hasError && totalsAsync.value == null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: ErrorState(
                message: "Couldn't load this month.",
                details: describeError(totalsAsync.error!),
                onRetry: () => ref.invalidate(monthTotalsProvider(_month)),
              ),
            ),
          _MonthGrid(month: _month, today: today, totals: totals, selected: _selected, onTap: _open),
          const SizedBox(height: Space.lg),
          Text('Tap a date to see its expenses.', textAlign: TextAlign.center, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.totals,
    required this.selected,
    required this.onTap,
  });

  final DateTime month;
  final DateTime today;
  final Map<DayKey, int> totals;
  final DayKey? selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final blanks = leadingBlanks(month);
    final days = daysInMonth(month);
    final cells = ((blanks + days) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: Space.xs + 2,
        crossAxisSpacing: Space.xs,
        childAspectRatio: 0.78,
      ),
      itemCount: cells,
      itemBuilder: (_, i) {
        final dayNumber = i - blanks + 1;
        if (dayNumber < 1 || dayNumber > days) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, dayNumber);
        final key = dayKeyOf(date);
        return CalendarDayCell(
          date: date,
          totalPaise: totals[key],
          isToday: date == today,
          isSelected: key == selected,
          isFuture: date.isAfter(today),
          onTap: () => onTap(date),
        );
      },
    );
  }
}

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.totalPaise,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime date;

  /// Null when the day has no expenses.
  final int? totalPaise;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = totalPaise;
    final background = isSelected
        ? AppColors.moss
        : total != null
        ? AppColors.mint
        : Colors.transparent;
    final dayColor = isSelected
        ? AppColors.white
        : isFuture
        ? AppColors.textSecondary.withValues(alpha: 0.5)
        : AppColors.ink;

    return Semantics(
      button: !isFuture,
      selected: isSelected,
      label: [
        formatFullDate(date),
        if (isToday) 'today',
        total == null ? 'no expenses' : '${formatInr(total)} spent',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.input),
          side: isToday && !isSelected ? const BorderSide(color: AppColors.moss, width: 1.6) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isFuture ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: Space.xs + 2),
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: dayColor,
                  ),
                ),
                const Spacer(),
                if (total != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatInrCompact(total),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.white : AppColors.mossDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
