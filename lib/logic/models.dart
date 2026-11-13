/// Data models and their JSON form. Pure Dart so they are easy to test.
library;

import 'dates.dart';

enum TxnKind { expense, income }

TxnKind _kindFrom(Object? v) =>
    v == 'income' ? TxnKind.income : TxnKind.expense;

String _kindTo(TxnKind k) => k == TxnKind.income ? 'income' : 'expense';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.kind,
    this.iconKey = 'tag',
    this.isFallback = false,
  });

  final String id;
  final String name;

  /// ARGB colour, for example 0xFF00A6A6.
  final int colorValue;
  final TxnKind kind;
  final String iconKey;

  /// The "Other" category of each kind. It cannot be deleted; deleting any
  /// other category moves its transactions here.
  final bool isFallback;

  Category copyWith({String? name, int? colorValue}) => Category(
    id: id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    kind: kind,
    iconKey: iconKey,
    isFallback: isFallback,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': colorValue,
    'kind': _kindTo(kind),
    'icon': iconKey,
    'fallback': isFallback,
  };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'] as String,
    name: j['name'] as String,
    colorValue: (j['color'] as num).toInt(),
    kind: _kindFrom(j['kind']),
    iconKey: (j['icon'] as String?) ?? 'tag',
    isFallback: (j['fallback'] as bool?) ?? false,
  );
}

class Txn {
  const Txn({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.categoryId,
    required this.date,
    this.note = '',
    this.recurringId,
  });

  final String id;
  final TxnKind kind;

  /// Always positive. [kind] says whether it is spending or income.
  final int amountCents;
  final String categoryId;
  final DateTime date;
  final String note;

  /// Set when a recurring bill created this expense.
  final String? recurringId;

  Txn copyWith({
    TxnKind? kind,
    int? amountCents,
    String? categoryId,
    DateTime? date,
    String? note,
  }) => Txn(
    id: id,
    kind: kind ?? this.kind,
    amountCents: amountCents ?? this.amountCents,
    categoryId: categoryId ?? this.categoryId,
    date: date ?? this.date,
    note: note ?? this.note,
    recurringId: recurringId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': _kindTo(kind),
    'amount': amountCents,
    'category': categoryId,
    'date': dateKey(date),
    'note': note,
    if (recurringId != null) 'recurring': recurringId,
  };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
    id: j['id'] as String,
    kind: _kindFrom(j['kind']),
    amountCents: (j['amount'] as num).toInt(),
    categoryId: j['category'] as String,
    date: parseDateKey(j['date'] as String) ?? dateOnly(DateTime.now()),
    note: (j['note'] as String?) ?? '',
    recurringId: j['recurring'] as String?,
  );
}

class RecurringBill {
  const RecurringBill({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.categoryId,
    required this.dayOfMonth,
    required this.startsOn,
    this.lastAppliedMonth = -1,
    this.active = true,
  });

  final String id;
  final String name;
  final int amountCents;
  final String categoryId;

  /// 1-31. In shorter months the bill is due on the last day.
  final int dayOfMonth;

  /// Occurrences due before this date are never created.
  final DateTime startsOn;

  /// [monthIndex] of the latest month already handled, or -1.
  final int lastAppliedMonth;
  final bool active;

  RecurringBill copyWith({
    String? name,
    int? amountCents,
    String? categoryId,
    int? dayOfMonth,
    DateTime? startsOn,
    int? lastAppliedMonth,
    bool? active,
  }) => RecurringBill(
    id: id,
    name: name ?? this.name,
    amountCents: amountCents ?? this.amountCents,
    categoryId: categoryId ?? this.categoryId,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    startsOn: startsOn ?? this.startsOn,
    lastAppliedMonth: lastAppliedMonth ?? this.lastAppliedMonth,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amountCents,
    'category': categoryId,
    'day': dayOfMonth,
    'startsOn': dateKey(startsOn),
    'lastApplied': lastAppliedMonth,
    'active': active,
  };

  factory RecurringBill.fromJson(Map<String, dynamic> j) => RecurringBill(
    id: j['id'] as String,
    name: j['name'] as String,
    amountCents: (j['amount'] as num).toInt(),
    categoryId: j['category'] as String,
    dayOfMonth: (j['day'] as num).toInt().clamp(1, 31),
    startsOn: parseDateKey(j['startsOn'] as String) ?? dateOnly(DateTime.now()),
    lastAppliedMonth: (j['lastApplied'] as num?)?.toInt() ?? -1,
    active: (j['active'] as bool?) ?? true,
  );
}

class Settings {
  const Settings({
    this.currencySymbol = '\u20B1',
    this.monthlyBudgetCents = 0,
    this.themeModeKey = 'system',
    this.onboarded = false,
  });

  final String currencySymbol;

  /// 0 means no budget has been set yet.
  final int monthlyBudgetCents;

  /// 'system', 'light' or 'dark'.
  final String themeModeKey;
  final bool onboarded;

  Settings copyWith({
    String? currencySymbol,
    int? monthlyBudgetCents,
    String? themeModeKey,
    bool? onboarded,
  }) => Settings(
    currencySymbol: currencySymbol ?? this.currencySymbol,
    monthlyBudgetCents: monthlyBudgetCents ?? this.monthlyBudgetCents,
    themeModeKey: themeModeKey ?? this.themeModeKey,
    onboarded: onboarded ?? this.onboarded,
  );

  Map<String, dynamic> toJson() => {
    'currency': currencySymbol,
    'budget': monthlyBudgetCents,
    'theme': themeModeKey,
    'onboarded': onboarded,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    currencySymbol: (j['currency'] as String?) ?? '\u20B1',
    monthlyBudgetCents: (j['budget'] as num?)?.toInt() ?? 0,
    themeModeKey: (j['theme'] as String?) ?? 'system',
    onboarded: (j['onboarded'] as bool?) ?? false,
  );
}

class AppData {
  AppData({
    required this.settings,
    required this.categories,
    required this.txns,
    required this.categoryBudgets,
    required this.bills,
  });

  Settings settings;
  final List<Category> categories;
  final List<Txn> txns;

  /// Category id to monthly limit in cents.
  final Map<String, int> categoryBudgets;
  final List<RecurringBill> bills;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'settings': settings.toJson(),
    'categories': [for (final c in categories) c.toJson()],
    'txns': [for (final t in txns) t.toJson()],
    'categoryBudgets': categoryBudgets,
    'bills': [for (final b in bills) b.toJson()],
  };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final budgets = <String, int>{};
    final rawBudgets = j['categoryBudgets'];
    if (rawBudgets is Map) {
      rawBudgets.forEach((k, v) {
        if (v is num) budgets['$k'] = v.toInt();
      });
    }
    return AppData(
      settings: Settings.fromJson(
        (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      categories: [
        for (final c in (j['categories'] as List? ?? const []))
          Category.fromJson((c as Map).cast<String, dynamic>()),
      ],
      txns: [
        for (final t in (j['txns'] as List? ?? const []))
          Txn.fromJson((t as Map).cast<String, dynamic>()),
      ],
      categoryBudgets: budgets,
      bills: [
        for (final b in (j['bills'] as List? ?? const []))
          RecurringBill.fromJson((b as Map).cast<String, dynamic>()),
      ],
    );
  }
}
