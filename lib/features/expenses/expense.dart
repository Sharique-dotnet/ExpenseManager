import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/dates.dart';

/// Max item name length. Mirrored in firestore.rules.
const maxItemNameLength = 60;

class Expense {
  const Expense({
    required this.id,
    required this.itemName,
    required this.amountPaise,
    required this.occurredAt,
    required this.localDate,
    this.createdAt,
    this.pendingSync = false,
  });

  final String id;
  final String itemName;
  final int amountPaise;
  final DateTime occurredAt;
  final DayKey localDate;

  /// Server creation time; null until a new write reaches the server.
  final DateTime? createdAt;

  /// True while the write exists only in the local cache (offline / unacknowledged).
  final bool pendingSync;

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final occurredAt = (data['occurredAt'] as Timestamp).toDate();
    return Expense(
      id: doc.id,
      itemName: data['itemName'] as String,
      amountPaise: (data['amountPaise'] as num).toInt(),
      occurredAt: occurredAt,
      localDate: (data['localDate'] as num?)?.toInt() ?? dayKeyOf(occurredAt),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      pendingSync: doc.metadata.hasPendingWrites,
    );
  }
}

/// What the form produces; validated before it reaches the repository.
class ExpenseDraft {
  const ExpenseDraft({required this.itemName, required this.amountPaise, required this.occurredAt});

  final String itemName;
  final int amountPaise;

  /// Local date-time the user picked. Its date becomes the expense's [Expense.localDate].
  final DateTime occurredAt;

  Map<String, dynamic> toFields() => {
    'itemName': itemName.trim(),
    'amountPaise': amountPaise,
    'occurredAt': Timestamp.fromDate(occurredAt),
    'localDate': dayKeyOf(occurredAt),
  };
}

String? validateItemName(String input) {
  final name = input.trim();
  if (name.isEmpty) return 'Enter what you spent on';
  if (name.length > maxItemNameLength) return 'Use $maxItemNameLength characters or fewer';
  return null;
}

int totalPaise(Iterable<Expense> expenses) => expenses.fold(0, (total, e) => total + e.amountPaise);

/// Newest first. Times are per-minute, so ties go to the most recently added
/// (unsynced = just added), then id, so the order never flickers between snapshots.
List<Expense> sortedNewestFirst(Iterable<Expense> expenses) {
  final pending = DateTime(9999);
  return expenses.toList()..sort((a, b) {
    final byTime = b.occurredAt.compareTo(a.occurredAt);
    if (byTime != 0) return byTime;
    final byCreated = (b.createdAt ?? pending).compareTo(a.createdAt ?? pending);
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  });
}

/// Sum of amounts per local date. Days without expenses are absent.
Map<DayKey, int> totalsByDay(Iterable<Expense> expenses) {
  final totals = <DayKey, int>{};
  for (final e in expenses) {
    totals[e.localDate] = (totals[e.localDate] ?? 0) + e.amountPaise;
  }
  return totals;
}
