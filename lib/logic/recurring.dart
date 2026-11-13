/// Turns recurring bills into expenses once their due day has arrived.
library;

import 'dart:math';

import 'dates.dart';
import 'models.dart';

class RecurringResult {
  const RecurringResult(this.created, this.bills);

  /// New expenses to add.
  final List<Txn> created;

  /// The bills with their progress marker updated (same order as the input).
  final List<RecurringBill> bills;
}

/// Creates the expenses that are due on or before [today].
///
/// * A bill only produces expenses dated on or after its [RecurringBill.startsOn].
/// * Months missed while the app was closed are caught up.
/// * Each month is handled once ([RecurringBill.lastAppliedMonth]), so deleting
///   a generated expense does not bring it back.
/// * Day 29-31 falls on the last day of shorter months.
RecurringResult applyDueBills({
  required List<RecurringBill> bills,
  required DateTime today,
  required String Function() newId,
}) {
  final created = <Txn>[];
  final updated = <RecurringBill>[];
  final todayIndex = monthIndex(today);

  for (final bill in bills) {
    if (!bill.active) {
      updated.add(bill);
      continue;
    }
    var index = max(monthIndex(bill.startsOn), bill.lastAppliedMonth + 1);
    // Never walk back more than five years.
    if (todayIndex - index > 60) index = todayIndex - 60;
    var last = bill.lastAppliedMonth;
    for (; index <= todayIndex; index++) {
      final month = monthFromIndex(index);
      final day = min(bill.dayOfMonth, daysInMonth(month.year, month.month));
      final due = DateTime(month.year, month.month, day);
      if (due.isAfter(today)) break;
      if (!due.isBefore(bill.startsOn)) {
        created.add(
          Txn(
            id: newId(),
            kind: TxnKind.expense,
            amountCents: bill.amountCents,
            categoryId: bill.categoryId,
            date: due,
            note: bill.name,
            recurringId: bill.id,
          ),
        );
      }
      last = index;
    }
    updated.add(
      last == bill.lastAppliedMonth
          ? bill
          : bill.copyWith(lastAppliedMonth: last),
    );
  }
  return RecurringResult(created, updated);
}
