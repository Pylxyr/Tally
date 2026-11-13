/// Default categories, the colour palette and sample data.
library;

import 'dart:math';

import 'dates.dart';
import 'ids.dart';
import 'models.dart';

const String fallbackExpenseId = 'other';
const String fallbackIncomeId = 'other_in';

/// Colours offered when creating or recolouring a category (ARGB).
const List<int> categoryPalette = [
  0xFF00A6A6, // teal
  0xFF3D7CFF, // blue
  0xFF7B5CFF, // violet
  0xFFC74BD6, // orchid
  0xFFE0568C, // rose
  0xFFF2A33A, // amber
  0xFF9BC53D, // lime
  0xFF2FB36D, // green
  0xFF5BC0EB, // sky
  0xFF6C7A89, // slate
  0xFF8D6E63, // clay
  0xFFB5838D, // mauve
];

const List<Category> defaultCategories = [
  Category(
    id: 'food',
    name: 'Food & dining',
    colorValue: 0xFFF2A33A,
    kind: TxnKind.expense,
    iconKey: 'restaurant',
  ),
  Category(
    id: 'groceries',
    name: 'Groceries',
    colorValue: 0xFF2FB36D,
    kind: TxnKind.expense,
    iconKey: 'grocery',
  ),
  Category(
    id: 'transport',
    name: 'Transport',
    colorValue: 0xFF3D7CFF,
    kind: TxnKind.expense,
    iconKey: 'transport',
  ),
  Category(
    id: 'bills',
    name: 'Bills & utilities',
    colorValue: 0xFF7B5CFF,
    kind: TxnKind.expense,
    iconKey: 'bolt',
  ),
  Category(
    id: 'home',
    name: 'Home & rent',
    colorValue: 0xFF00A6A6,
    kind: TxnKind.expense,
    iconKey: 'home',
  ),
  Category(
    id: 'health',
    name: 'Health',
    colorValue: 0xFFE0568C,
    kind: TxnKind.expense,
    iconKey: 'health',
  ),
  Category(
    id: 'shopping',
    name: 'Shopping',
    colorValue: 0xFFC74BD6,
    kind: TxnKind.expense,
    iconKey: 'shopping',
  ),
  Category(
    id: 'fun',
    name: 'Fun & leisure',
    colorValue: 0xFF5BC0EB,
    kind: TxnKind.expense,
    iconKey: 'fun',
  ),
  Category(
    id: 'travel',
    name: 'Travel',
    colorValue: 0xFF9BC53D,
    kind: TxnKind.expense,
    iconKey: 'travel',
  ),
  Category(
    id: fallbackExpenseId,
    name: 'Other',
    colorValue: 0xFF6C7A89,
    kind: TxnKind.expense,
    iconKey: 'tag',
    isFallback: true,
  ),
  Category(
    id: 'salary',
    name: 'Salary',
    colorValue: 0xFF2FB36D,
    kind: TxnKind.income,
    iconKey: 'wallet',
  ),
  Category(
    id: 'side',
    name: 'Side income',
    colorValue: 0xFF5BC0EB,
    kind: TxnKind.income,
    iconKey: 'work',
  ),
  Category(
    id: 'gift',
    name: 'Gifts',
    colorValue: 0xFFF2A33A,
    kind: TxnKind.income,
    iconKey: 'gift',
  ),
  Category(
    id: fallbackIncomeId,
    name: 'Other income',
    colorValue: 0xFF6C7A89,
    kind: TxnKind.income,
    iconKey: 'tag',
    isFallback: true,
  ),
];

AppData freshData() => AppData(
  settings: const Settings(),
  categories: [...defaultCategories],
  txns: [],
  categoryBudgets: {},
  bills: [],
);

/// Makes sure both "Other" categories exist, e.g. after hand-edited data.
void ensureFallbackCategories(AppData data) {
  for (final c in defaultCategories) {
    if (c.isFallback && !data.categories.any((x) => x.id == c.id)) {
      data.categories.add(c);
    }
  }
}

/// A month and a half of believable spending ending [today]. Never dated in
/// the future. The same [seed] gives the same data.
List<Txn> sampleTransactions(DateTime today, {int seed = 7}) {
  final rng = Random(seed);
  final out = <Txn>[];

  void add(TxnKind kind, int units, String cat, DateTime day, String note) {
    if (dayKey(day) > dayKey(today)) return;
    out.add(
      Txn(
        id: newId(),
        kind: kind,
        amountCents: units * 100,
        categoryId: cat,
        date: day,
        note: note,
      ),
    );
  }

  int pick(int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

  final firstOfThisMonth = DateTime(today.year, today.month);
  final firstOfLastMonth = addMonths(firstOfThisMonth, -1);

  for (final first in [firstOfLastMonth, firstOfThisMonth]) {
    add(TxnKind.income, 32000, 'salary', first, 'Salary');
    add(TxnKind.expense, 8500, 'home', first, 'Rent');
    add(TxnKind.expense, 1850, 'bills', addDays(first, 4), 'Electricity');
    add(TxnKind.expense, 1299, 'bills', addDays(first, 9), 'Internet');
  }

  const meals = ['Lunch', 'Coffee', 'Dinner', 'Snacks', 'Milk tea'];
  const outings = ['Cinema', 'Games', 'Streaming', 'Concert'];
  final start = addDays(today, -44);
  for (var i = 0; i < 45; i++) {
    final day = addDays(start, i);
    if (rng.nextInt(10) < 8) {
      add(
        TxnKind.expense,
        pick(90, 380),
        'food',
        day,
        meals[rng.nextInt(meals.length)],
      );
    }
    if (rng.nextInt(10) < 4) {
      add(TxnKind.expense, pick(40, 220), 'transport', day, 'Commute');
    }
    if (day.weekday == DateTime.saturday) {
      add(TxnKind.expense, pick(900, 2400), 'groceries', day, 'Groceries');
    }
    if (rng.nextInt(10) == 0) {
      add(TxnKind.expense, pick(300, 1800), 'shopping', day, 'Shopping');
    }
    if (rng.nextInt(12) == 0) {
      add(
        TxnKind.expense,
        pick(250, 1400),
        'fun',
        day,
        outings[rng.nextInt(outings.length)],
      );
    }
    if (rng.nextInt(20) == 0) {
      add(TxnKind.expense, pick(200, 1200), 'health', day, 'Pharmacy');
    }
  }
  return out;
}
