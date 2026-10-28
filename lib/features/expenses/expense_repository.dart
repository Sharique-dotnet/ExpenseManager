import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/dates.dart';
import 'expense.dart';

/// Reads and writes `users/{uid}/expenses`.
class ExpenseRepository {
  ExpenseRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _expenses => _db.collection('users').doc(uid).collection('expenses');

  /// Live expenses whose local date is within [from]..[to] (inclusive), newest first.
  /// One query per range; callers group locally (no per-day reads).
  Stream<List<Expense>> watchDays(DayKey from, DayKey to) => _expenses
      .where('localDate', isGreaterThanOrEqualTo: from)
      .where('localDate', isLessThanOrEqualTo: to)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => sortedNewestFirst(snap.docs.map(Expense.fromDoc)));

  /// Client-generated id, so retrying a failed save can't create duplicates.
  String newId() => _expenses.doc().id;

  Future<void> create(String id, ExpenseDraft draft) => _expenses.doc(id).set({
    ...draft.toFields(),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> update(String id, ExpenseDraft draft) =>
      _expenses.doc(id).update({...draft.toFields(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> delete(String id) => _expenses.doc(id).delete();
}

/// Firestore write futures only complete once the server acknowledges them, which
/// never happens while offline. Waits up to [timeout]: true = confirmed by the
/// server, false = applied locally and queued for sync. Errors before the timeout
/// are rethrown; errors after it (a queued write rejected on reconnect) go to [onLateError].
Future<bool> waitForServer(
  Future<void> write, {
  required void Function(Object error) onLateError,
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    await write.timeout(timeout);
    return true;
  } on TimeoutException {
    unawaited(write.catchError(onLateError));
    return false;
  }
}
