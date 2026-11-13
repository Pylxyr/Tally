import 'package:flutter_test/flutter_test.dart';
import 'package:tally/logic/budget_math.dart';
import 'package:tally/logic/csv_export.dart';
import 'package:tally/logic/dates.dart';
import 'package:tally/logic/defaults.dart';
import 'package:tally/logic/models.dart';
import 'package:tally/logic/money.dart';
import 'package:tally/logic/recurring.dart';

int _n = 0;
String _id() => 'id${_n++}';

Txn expense(int units, DateTime date, {String cat = 'food'}) => Txn(
  id: _id(),
  kind: TxnKind.expense,
  amountCents: units * 100,
  categoryId: cat,
  date: date,
);

Txn income(int units, DateTime date) => Txn(
  id: _id(),
  kind: TxnKind.income,
  amountCents: units * 100,
  categoryId: 'salary',
  date: date,
);

void main() {
  group('month boundaries', () {
    test('days in month, including leap years', () {
      expect(daysInMonth(2026, 1), 31);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2028, 2), 29);
      expect(daysInMonth(1900, 2), 28);
      expect(daysInMonth(2000, 2), 29);
      expect(daysInMonth(2026, 4), 30);
      expect(daysInMonth(2026, 12), 31);
    });

    test('days left counts today', () {
      expect(daysLeftInMonth(DateTime(2026, 11, 1)), 30);
      expect(daysLeftInMonth(DateTime(2026, 11, 12)), 19);
      expect(daysLeftInMonth(DateTime(2026, 11, 30)), 1);
      expect(daysLeftInMonth(DateTime(2028, 2, 29)), 1);
    });

    test('month arithmetic crosses year boundaries', () {
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
      expect(
        monthFromIndex(monthIndex(DateTime(2026, 11, 12))),
        DateTime(2026, 11),
      );
    });

    test('only same-month expenses are counted', () {
      final txns = [
        expense(100, DateTime(2026, 10, 31)),
        expense(200, DateTime(2026, 11, 1)),
        expense(300, DateTime(2026, 11, 30)),
        expense(400, DateTime(2026, 12, 1)),
        income(5000, DateTime(2026, 11, 15)),
      ];
      final nov = DateTime(2026, 11);
      expect(spentInMonth(txns, nov), 50000);
      expect(incomeInMonth(txns, nov), 500000);
    });

    test('date keys round-trip and reject impossible dates', () {
      expect(dateKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(parseDateKey('2026-03-05'), DateTime(2026, 3, 5));
      expect(parseDateKey('2026-02-30'), isNull);
      expect(parseDateKey('nonsense'), isNull);
    });
  });

  group('safe to spend today', () {
    test('first day of the month with nothing spent', () {
      final today = DateTime(2026, 11, 1);
      final v = safeToSpendToday(
        budgetCents: 3000000,
        txns: const [],
        today: today,
      );
      // 30,000 over 30 days.
      expect(v, closeTo(100000, 0.0001));
    });

    test('uses spending before today and subtracts today', () {
      final today = DateTime(2026, 11, 11); // 20 days left including today
      final txns = [
        expense(2000, DateTime(2026, 11, 3)),
        expense(1000, DateTime(2026, 11, 10)),
        expense(150, today),
      ];
      // (30,000 - 3,000) / 20 = 1,350 per day, minus 150 spent today.
      final v = safeToSpendToday(
        budgetCents: 3000000,
        txns: txns,
        today: today,
      );
      expect(v, closeTo(120000, 0.0001));
      expect(
        dailyLimit(budgetCents: 3000000, txns: txns, today: today),
        closeTo(135000, 0.0001),
      );
    });

    test('ignores income, other months and later days', () {
      final today = DateTime(2026, 11, 11);
      final txns = [
        income(9999, DateTime(2026, 11, 2)),
        expense(5000, DateTime(2026, 10, 11)),
        expense(5000, DateTime(2026, 11, 20)),
      ];
      final v = safeToSpendToday(
        budgetCents: 2000000,
        txns: txns,
        today: today,
      );
      expect(v, closeTo(2000000 / 20, 0.0001));
    });

    test('is negative once today passes its limit', () {
      final today = DateTime(2026, 11, 30); // last day: 1 day left
      final txns = [expense(2800, DateTime(2026, 11, 10)), expense(300, today)];
      // Remaining 200 for one day, minus 300 spent.
      final v = safeToSpendToday(budgetCents: 300000, txns: txns, today: today);
      expect(v, closeTo(-10000, 0.0001));
      expect(v < 0, isTrue);
    });

    test('goes negative for the day when the budget is already spent', () {
      final today = DateTime(2026, 11, 15);
      // 40,000 spent against a 30,000 budget.
      final txns = [expense(40000, DateTime(2026, 11, 5))];
      final v = safeToSpendToday(
        budgetCents: 3000000,
        txns: txns,
        today: today,
      );
      expect(v < 0, isTrue);
    });

    test('rounds down to whole units for display', () {
      expect(floorToUnits(12999.9), 129);
      expect(floorToUnits(-1), -1);
      expect(floorToUnits(0), 0);
    });
  });

  group('pace', () {
    test('tick sits at the share of the month elapsed', () {
      final p = paceFor(
        budgetCents: 3000000,
        spentCents: 0,
        today: DateTime(2026, 11, 15),
      );
      expect(p.paceFraction, closeTo(0.5, 0.0001));
      final end = paceFor(
        budgetCents: 3000000,
        spentCents: 0,
        today: DateTime(2026, 11, 30),
      );
      expect(end.paceFraction, closeTo(1.0, 0.0001));
      final feb = paceFor(
        budgetCents: 100,
        spentCents: 0,
        today: DateTime(2028, 2, 29),
      );
      expect(feb.paceFraction, closeTo(1.0, 0.0001));
    });

    test('delta is spent minus the evenly paced amount', () {
      final p = paceFor(
        budgetCents: 3000000,
        spentCents: 1800000,
        today: DateTime(2026, 11, 15),
      );
      expect(p.spentFraction, closeTo(0.6, 0.0001));
      expect(p.deltaCents, 300000); // 18,000 spent vs 15,000 expected
      final under = paceFor(
        budgetCents: 3000000,
        spentCents: 1000000,
        today: DateTime(2026, 11, 15),
      );
      expect(under.deltaCents, -500000);
    });

    test('no budget gives a zero fraction', () {
      final p = paceFor(
        budgetCents: 0,
        spentCents: 500,
        today: DateTime(2026, 11, 15),
      );
      expect(p.spentFraction, 0);
    });

    test('last seven days run oldest to newest and include today', () {
      final today = DateTime(2026, 11, 2);
      final txns = [
        expense(10, DateTime(2026, 10, 27)),
        expense(20, DateTime(2026, 10, 31)),
        expense(5, DateTime(2026, 10, 31)),
        expense(7, today),
        expense(99, DateTime(2026, 10, 26)), // too old
        income(500, today), // not spending
      ];
      final days = lastDaysSpending(txns, today);
      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 10, 27));
      expect(days.last.day, today);
      expect(days.first.cents, 1000);
      expect(days[4].cents, 2500);
      expect(days.last.cents, 700);
      expect(days[1].cents, 0);
    });

    test('category totals are ranked largest first', () {
      final txns = [
        expense(10, DateTime(2026, 11, 1), cat: 'food'),
        expense(30, DateTime(2026, 11, 2), cat: 'bills'),
        expense(5, DateTime(2026, 11, 3), cat: 'food'),
        expense(99, DateTime(2026, 10, 3), cat: 'travel'),
      ];
      final ranked = spendingByCategory(txns, DateTime(2026, 11));
      expect(ranked, hasLength(2));
      expect(ranked.first.key, 'bills');
      expect(ranked.first.value, 3000);
      expect(ranked.last.value, 1500);
    });
  });

  group('recurring bills', () {
    RecurringBill bill({
      required int day,
      required DateTime startsOn,
      int last = -1,
      bool active = true,
    }) => RecurringBill(
      id: 'rent',
      name: 'Rent',
      amountCents: 850000,
      categoryId: 'home',
      dayOfMonth: day,
      startsOn: startsOn,
      lastAppliedMonth: last,
      active: active,
    );

    test('is added on the due day, not before', () {
      final b = bill(day: 15, startsOn: DateTime(2026, 11, 1));
      final before = applyDueBills(
        bills: [b],
        today: DateTime(2026, 11, 14),
        newId: _id,
      );
      expect(before.created, isEmpty);
      final onDay = applyDueBills(
        bills: [b],
        today: DateTime(2026, 11, 15),
        newId: _id,
      );
      expect(onDay.created, hasLength(1));
      expect(onDay.created.first.date, DateTime(2026, 11, 15));
      expect(onDay.created.first.amountCents, 850000);
      expect(onDay.created.first.recurringId, 'rent');
      expect(onDay.created.first.kind, TxnKind.expense);
    });

    test('is not added twice for the same month', () {
      final b = bill(day: 5, startsOn: DateTime(2026, 11, 1));
      final first = applyDueBills(
        bills: [b],
        today: DateTime(2026, 11, 20),
        newId: _id,
      );
      expect(first.created, hasLength(1));
      final again = applyDueBills(
        bills: first.bills,
        today: DateTime(2026, 11, 28),
        newId: _id,
      );
      expect(again.created, isEmpty);
    });

    test('a deleted generated expense does not come back', () {
      final b = bill(day: 5, startsOn: DateTime(2026, 11, 1));
      final first = applyDueBills(
        bills: [b],
        today: DateTime(2026, 11, 6),
        newId: _id,
      );
      // The user deletes the expense; only the bill's marker remains.
      final later = applyDueBills(
        bills: first.bills,
        today: DateTime(2026, 11, 7),
        newId: _id,
      );
      expect(later.created, isEmpty);
    });

    test('catches up months missed while the app was closed', () {
      final b = bill(day: 1, startsOn: DateTime(2026, 8, 20));
      final r = applyDueBills(
        bills: [b],
        today: DateTime(2026, 11, 12),
        newId: _id,
      );
      // Sept 1, Oct 1 and Nov 1. Aug 1 is before the bill existed.
      expect(r.created.map((t) => t.date).toList(), [
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
        DateTime(2026, 11, 1),
      ]);
    });

    test('a bill created after this month\'s due day waits for next month', () {
      final b = bill(day: 5, startsOn: DateTime(2026, 11, 12));
      final r = applyDueBills(
        bills: [b],
        today: DateTime(2026, 11, 12),
        newId: _id,
      );
      expect(r.created, isEmpty);
      final next = applyDueBills(
        bills: r.bills,
        today: DateTime(2026, 12, 5),
        newId: _id,
      );
      expect(next.created, hasLength(1));
      expect(next.created.first.date, DateTime(2026, 12, 5));
    });

    test('a bill created on its due day is added straight away', () {
      final b = bill(day: 12, startsOn: DateTime(2026, 11, 12));
      final r = applyDueBills(
        bills: [b],
        today: DateTime(2026, 11, 12),
        newId: _id,
      );
      expect(r.created, hasLength(1));
    });

    test('day 31 falls on the last day of shorter months', () {
      final b = bill(day: 31, startsOn: DateTime(2026, 1, 1));
      final r = applyDueBills(
        bills: [b],
        today: DateTime(2026, 4, 30),
        newId: _id,
      );
      expect(r.created.map((t) => t.date).toList(), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('leap year February uses the 29th', () {
      final b = bill(day: 30, startsOn: DateTime(2028, 2, 1));
      final r = applyDueBills(
        bills: [b],
        today: DateTime(2028, 2, 29),
        newId: _id,
      );
      expect(r.created.single.date, DateTime(2028, 2, 29));
    });

    test('works across a year boundary', () {
      final b = bill(day: 2, startsOn: DateTime(2026, 12, 1));
      final r = applyDueBills(
        bills: [b],
        today: DateTime(2027, 1, 3),
        newId: _id,
      );
      expect(r.created.map((t) => t.date).toList(), [
        DateTime(2026, 12, 2),
        DateTime(2027, 1, 2),
      ]);
    });

    test('paused bills create nothing', () {
      final b = bill(day: 1, startsOn: DateTime(2026, 1, 1), active: false);
      final r = applyDueBills(
        bills: [b],
        today: DateTime(2026, 11, 12),
        newId: _id,
      );
      expect(r.created, isEmpty);
      expect(r.bills.single.lastAppliedMonth, -1);
    });
  });

  group('money', () {
    test('formats with grouping and only needed decimals', () {
      expect(formatMoney(125000, '\u20B1'), '\u20B11,250');
      expect(formatMoney(125050, '\u20B1'), '\u20B11,250.50');
      expect(formatMoney(5, '\$'), '\$0.05');
      expect(formatMoney(0, '\$'), '\$0');
      expect(formatMoney(-30000, '\$'), '\u2212\$300');
      expect(formatMoney(100000000, '\$'), '\$1,000,000');
    });

    test('parses typed amounts', () {
      expect(parseCents('1250'), 125000);
      expect(parseCents('1250.5'), 125050);
      expect(parseCents('.5'), 50);
      expect(parseCents('12.34'), 1234);
      expect(parseCents(''), isNull);
      expect(parseCents('.'), isNull);
      expect(parseCents('1.234'), isNull);
      expect(parseCents('abc'), isNull);
      expect(centsToInput(125050), '1250.50');
      expect(centsToInput(125000), '1250');
    });
  });

  group('data', () {
    test('csv escapes commas and quotes', () {
      final data = freshData();
      data.txns.add(
        Txn(
          id: 'a',
          kind: TxnKind.expense,
          amountCents: 12345,
          categoryId: 'food',
          date: DateTime(2026, 11, 3),
          note: 'Lunch, "big" one',
        ),
      );
      final csv = buildCsv(data);
      expect(csv.contains('2026-11-03,expense,Food & dining,123.45,'), isTrue);
      expect(csv.contains('"Lunch, ""big"" one"'), isTrue);
    });

    test('data survives a JSON round trip', () {
      final data = freshData();
      data.settings = data.settings.copyWith(monthlyBudgetCents: 3000000);
      data.categoryBudgets['food'] = 500000;
      data.txns.addAll(sampleTransactions(DateTime(2026, 11, 12)));
      final copy = AppData.fromJson(data.toJson());
      expect(copy.txns.length, data.txns.length);
      expect(copy.settings.monthlyBudgetCents, 3000000);
      expect(copy.categoryBudgets['food'], 500000);
      expect(copy.categories.length, data.categories.length);
    });

    test('sample data is never dated in the future', () {
      final today = DateTime(2026, 11, 12);
      final txns = sampleTransactions(today);
      expect(txns.isNotEmpty, isTrue);
      expect(txns.every((t) => dayKey(t.date) <= dayKey(today)), isTrue);
    });
  });
}
