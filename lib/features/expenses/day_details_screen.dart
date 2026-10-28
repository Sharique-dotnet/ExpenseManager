import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import 'expense_widgets.dart';

class DayDetailsScreen extends StatelessWidget {
  const DayDetailsScreen({super.key, required this.day});

  final DayKey day;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DayExpensesScaffold(
      day: day,
      totalLabel: 'Total spent on this date',
      emptyTitle: 'No expenses on this date.',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.page, Space.md),
        child: Row(
          children: [
            const BackButton(),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatFullDate(dateOfKey(day)), style: text.headlineMedium!.copyWith(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text('Daily expense summary', style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
