import 'dart:async';

import 'package:flutter/widgets.dart';

import '../logic/csv_export.dart';
import '../logic/dates.dart';
import '../logic/defaults.dart';
import '../logic/ids.dart';
import '../logic/models.dart';
import '../logic/money.dart';
import '../logic/recurring.dart';
import 'store.dart';

/// All app state. UI listens to this and calls the methods below; every
/// change is saved to disk straight away.
class AppState extends ChangeNotifier {
  AppState(this._store, this._data, {this.recoveredFromCorruption = false});

  final Store _store;
  final AppData _data;

  /// True when saved data could not be read at start-up.
  bool recoveredFromCorruption;

  /// The expense or income that was just added, so its row can animate in.
  String? lastAddedId;

  static Future<AppState> load() async {
    final store = await Store.open();
    final data = await store.read() ?? freshData();
    ensureFallbackCategories(data);
    final state = AppState(
      store,
      data,
      recoveredFromCorruption: store.recoveredFromCorruption,
    );
    state._applyRecurring();
    return state;
  }

  // ---- reading -----------------------------------------------------------

  Settings get settings => _data.settings;
  List<Category> get categories => _data.categories;
  List<Txn> get txns => _data.txns;
  List<RecurringBill> get bills => _data.bills;
  Map<String, int> get categoryBudgets => _data.categoryBudgets;
  AppData get data => _data;

  DateTime get today => dateOnly(DateTime.now());

  String get symbol => _data.settings.currencySymbol;

  String money(int cents, {bool showPlus = false}) =>
      formatMoney(cents, symbol, showPlus: showPlus);

  List<Category> categoriesOf(TxnKind kind) => [
    for (final c in _data.categories)
      if (c.kind == kind) c,
  ];

  Category categoryById(String id, {TxnKind kind = TxnKind.expense}) {
    for (final c in _data.categories) {
      if (c.id == id) return c;
    }
    final fallback = kind == TxnKind.income
        ? fallbackIncomeId
        : fallbackExpenseId;
    return _data.categories.firstWhere((c) => c.id == fallback);
  }

  Category categoryFor(Txn t) => categoryById(t.categoryId, kind: t.kind);

  // ---- settings ----------------------------------------------------------

  void setBudget(int cents) {
    _data.settings = _data.settings.copyWith(monthlyBudgetCents: cents);
    _commit();
  }

  void setCurrency(String symbol) {
    final s = symbol.trim();
    if (s.isEmpty) return;
    _data.settings = _data.settings.copyWith(currencySymbol: s);
    _commit();
  }

  void setThemeMode(String key) {
    _data.settings = _data.settings.copyWith(themeModeKey: key);
    _commit();
  }

  void completeOnboarding({
    required String currency,
    required int budgetCents,
    bool withSampleData = false,
  }) {
    _data.settings = _data.settings.copyWith(
      currencySymbol: currency.trim().isEmpty ? null : currency.trim(),
      monthlyBudgetCents: budgetCents,
      onboarded: true,
    );
    if (withSampleData) _addSample();
    _commit();
  }

  /// Deletes everything and returns to first-run setup.
  void deleteAllData() {
    final fresh = freshData();
    _data.settings = fresh.settings;
    _data.categories
      ..clear()
      ..addAll(fresh.categories);
    _data.txns.clear();
    _data.categoryBudgets.clear();
    _data.bills.clear();
    lastAddedId = null;
    _commit();
  }

  // ---- transactions ------------------------------------------------------

  void addTxn(Txn t) {
    _data.txns.add(t);
    _markAdded(t.id);
    _commit();
  }

  void updateTxn(Txn t) {
    final i = _data.txns.indexWhere((x) => x.id == t.id);
    if (i < 0) return;
    _data.txns[i] = t;
    _commit();
  }

  /// Removes and returns the transaction so the caller can offer Undo.
  Txn? deleteTxn(String id) {
    final i = _data.txns.indexWhere((x) => x.id == id);
    if (i < 0) return null;
    final removed = _data.txns.removeAt(i);
    _commit();
    return removed;
  }

  void restoreTxn(Txn t) {
    _data.txns.add(t);
    _markAdded(t.id);
    _commit();
  }

  void _markAdded(String id) {
    lastAddedId = id;
    Timer(const Duration(milliseconds: 700), () {
      if (lastAddedId == id) lastAddedId = null;
    });
  }

  // ---- categories & budgets ----------------------------------------------

  void addCategory(String name, int colorValue, TxnKind kind) {
    _data.categories.add(
      Category(
        id: newId(),
        name: name.trim(),
        colorValue: colorValue,
        kind: kind,
      ),
    );
    _commit();
  }

  void updateCategory(String id, {String? name, int? colorValue}) {
    final i = _data.categories.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _data.categories[i] = _data.categories[i].copyWith(
      name: name?.trim(),
      colorValue: colorValue,
    );
    _commit();
  }

  /// Deletes a category. Its transactions and bills move to "Other".
  /// Returns false for the protected "Other" categories.
  bool deleteCategory(String id) {
    final i = _data.categories.indexWhere((c) => c.id == id);
    if (i < 0 || _data.categories[i].isFallback) return false;
    final kind = _data.categories[i].kind;
    final target = kind == TxnKind.income
        ? fallbackIncomeId
        : fallbackExpenseId;
    for (var k = 0; k < _data.txns.length; k++) {
      final t = _data.txns[k];
      if (t.categoryId == id) _data.txns[k] = t.copyWith(categoryId: target);
    }
    for (var k = 0; k < _data.bills.length; k++) {
      final b = _data.bills[k];
      if (b.categoryId == id) {
        _data.bills[k] = b.copyWith(categoryId: fallbackExpenseId);
      }
    }
    _data.categoryBudgets.remove(id);
    _data.categories.removeAt(i);
    _commit();
    return true;
  }

  int txnCountFor(String categoryId) =>
      _data.txns.where((t) => t.categoryId == categoryId).length;

  void setCategoryBudget(String categoryId, int? cents) {
    if (cents == null || cents <= 0) {
      _data.categoryBudgets.remove(categoryId);
    } else {
      _data.categoryBudgets[categoryId] = cents;
    }
    _commit();
  }

  // ---- recurring bills ---------------------------------------------------

  void addBill({
    required String name,
    required int amountCents,
    required String categoryId,
    required int dayOfMonth,
  }) {
    _data.bills.add(
      RecurringBill(
        id: newId(),
        name: name.trim(),
        amountCents: amountCents,
        categoryId: categoryId,
        dayOfMonth: dayOfMonth,
        startsOn: today,
      ),
    );
    _applyRecurring();
    _commit();
  }

  void updateBill(RecurringBill bill) {
    final i = _data.bills.indexWhere((b) => b.id == bill.id);
    if (i < 0) return;
    _data.bills[i] = bill;
    _applyRecurring();
    _commit();
  }

  void setBillActive(String id, bool active) {
    final i = _data.bills.indexWhere((b) => b.id == id);
    if (i < 0) return;
    final b = _data.bills[i];
    // Resuming a bill never back-fills the months it was paused.
    _data.bills[i] = active
        ? b.copyWith(active: true, startsOn: today)
        : b.copyWith(active: false);
    _applyRecurring();
    _commit();
  }

  void deleteBill(String id) {
    _data.bills.removeWhere((b) => b.id == id);
    _commit();
  }

  /// Adds expenses for bills that have come due. Runs at start-up and
  /// whenever the app comes back to the foreground.
  void refresh() {
    _applyRecurring();
    notifyListeners();
    _store.save(_data);
  }

  void _applyRecurring() {
    final result = applyDueBills(
      bills: _data.bills,
      today: today,
      newId: newId,
    );
    if (result.created.isEmpty && !_billsChanged(result.bills)) return;
    _data.txns.addAll(result.created);
    for (var i = 0; i < result.bills.length; i++) {
      _data.bills[i] = result.bills[i];
    }
  }

  bool _billsChanged(List<RecurringBill> next) {
    for (var i = 0; i < next.length; i++) {
      if (!identical(next[i], _data.bills[i])) return true;
    }
    return false;
  }

  // ---- sample data & export ----------------------------------------------

  void loadSampleData() {
    _addSample();
    _commit();
  }

  void _addSample() {
    _data.txns.addAll(sampleTransactions(today));
    if (_data.settings.monthlyBudgetCents <= 0) {
      _data.settings = _data.settings.copyWith(monthlyBudgetCents: 3000000);
    }
  }

  String csv() => buildCsv(_data);

  // ---- internals ---------------------------------------------------------

  void _commit() {
    notifyListeners();
    _store.save(_data);
  }
}

/// Gives widgets access to the [AppState] and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  /// Use in `build`: the widget rebuilds when data changes.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this widget.');
    return scope!.notifier!;
  }

  /// Use in event handlers: reads state without subscribing.
  static AppState read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    assert(element != null, 'No AppScope found above this widget.');
    return (element!.widget as AppScope).notifier!;
  }
}
