/// The budget maths behind the dashboard. Pure functions, all in cents.
library;

import 'dates.dart';
import 'models.dart';

/// Total spending (expenses only) in the calendar month of [month].
int spentInMonth(Iterable<Txn> txns, DateTime month) {
  var total = 0;
  for (final t in txns) {
    if (t.kind == TxnKind.expense && isSameMonth(t.date, month)) {
      total += t.amountCents;
    }
  }
  return total;
}

int incomeInMonth(Iterable<Txn> txns, DateTime month) {
  var total = 0;
  for (final t in txns) {
    if (t.kind == TxnKind.income && isSameMonth(t.date, month)) {
      total += t.amountCents;
    }
  }
  return total;
}

/// Spending earlier in [today]'s month, not counting today.
int spentBeforeToday(Iterable<Txn> txns, DateTime today) {
  var total = 0;
  for (final t in txns) {
    if (t.kind == TxnKind.expense &&
        isSameMonth(t.date, today) &&
        t.date.day < today.day) {
      total += t.amountCents;
    }
  }
  return total;
}

int spentOnDay(Iterable<Txn> txns, DateTime day) {
  var total = 0;
  for (final t in txns) {
    if (t.kind == TxnKind.expense && isSameDay(t.date, day)) {
      total += t.amountCents;
    }
  }
  return total;
}

/// Today's spending limit: what is left of the budget after earlier days,
/// spread over the days left (today included).
double dailyLimit({
  required int budgetCents,
  required Iterable<Txn> txns,
  required DateTime today,
}) {
  final remaining = budgetCents - spentBeforeToday(txns, today);
  return remaining / daysLeftInMonth(today);
}

/// How much can still be spent today and stay on this month's budget:
/// (budget - spending before today) / days left in the month - today's
/// spending. Negative when today is over its limit. In cents.
double safeToSpendToday({
  required int budgetCents,
  required Iterable<Txn> txns,
  required DateTime today,
}) {
  return dailyLimit(budgetCents: budgetCents, txns: txns, today: today) -
      spentOnDay(txns, today);
}

class Pace {
  const Pace({
    required this.spentFraction,
    required this.paceFraction,
    required this.deltaCents,
  });

  /// Spent / budget. Can be above 1 when over budget; 0 without a budget.
  final double spentFraction;

  /// Share of the month elapsed at the end of today (day / days in month).
  /// This is where the progress bar's tick sits.
  final double paceFraction;

  /// Spent minus the evenly-paced amount. Positive means ahead of pace.
  final int deltaCents;
}

Pace paceFor({
  required int budgetCents,
  required int spentCents,
  required DateTime today,
}) {
  final days = daysInMonth(today.year, today.month);
  final pace = today.day / days;
  final expected = (budgetCents * pace).round();
  return Pace(
    spentFraction: budgetCents > 0 ? spentCents / budgetCents : 0,
    paceFraction: pace,
    deltaCents: spentCents - expected,
  );
}

class DayTotal {
  const DayTotal(this.day, this.cents);
  final DateTime day;
  final int cents;
}

/// Spending per day for the [days] days ending today, oldest first.
List<DayTotal> lastDaysSpending(
  Iterable<Txn> txns,
  DateTime today, {
  int days = 7,
}) {
  final start = addDays(today, -(days - 1));
  final first = dayKey(start);
  final last = dayKey(today);
  final totals = <int, int>{};
  for (final t in txns) {
    if (t.kind != TxnKind.expense) continue;
    final k = dayKey(t.date);
    if (k >= first && k <= last) totals[k] = (totals[k] ?? 0) + t.amountCents;
  }
  return [
    for (var i = 0; i < days; i++)
      DayTotal(addDays(start, i), totals[dayKey(addDays(start, i))] ?? 0),
  ];
}

/// Expense totals per category for [month], largest first.
List<MapEntry<String, int>> spendingByCategory(
  Iterable<Txn> txns,
  DateTime month,
) {
  final totals = <String, int>{};
  for (final t in txns) {
    if (t.kind == TxnKind.expense && isSameMonth(t.date, month)) {
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amountCents;
    }
  }
  final list = totals.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return list;
}
