import 'package:flutter_test/flutter_test.dart';
import 'package:tally/logic/csv_export.dart';
import 'package:tally/logic/csv_import.dart';
import 'package:tally/logic/defaults.dart';
import 'package:tally/logic/models.dart';

int _n = 0;
String _id() => 'n${_n++}';

Txn _txn(
  String id,
  TxnKind kind,
  int cents,
  String category,
  DateTime date, [
  String note = '',
]) => Txn(
  id: id,
  kind: kind,
  amountCents: cents,
  categoryId: category,
  date: date,
  note: note,
);

AppData _source() {
  final data = freshData();
  data.categories.add(
    const Category(
      id: 'pets',
      name: 'Pets',
      colorValue: 0xFF123456,
      kind: TxnKind.expense,
    ),
  );
  data.txns.addAll([
    _txn('a', TxnKind.expense, 450662, 'pets', DateTime(2026, 11, 13), 'Food, "big" bag'),
    _txn('b', TxnKind.expense, 12000, 'food', DateTime(2026, 11, 13), 'Lunch'),
    _txn('c', TxnKind.expense, 12000, 'food', DateTime(2026, 11, 13), 'Lunch'),
    _txn('d', TxnKind.income, 3000000, 'salary', DateTime(2026, 11, 1), 'Line 1\nLine 2'),
    _txn('e', TxnKind.expense, 99, fallbackExpenseId, DateTime(2026, 10, 2)),
  ]);
  return data;
}

void main() {
  group('parseCsv', () {
    test('handles quotes, commas, line breaks and a BOM', () {
      final rows = parseCsv('﻿a,b\r\n"x,1","he said ""hi"""\n"l1\nl2",z\n');
      expect(rows, [
        ['a', 'b'],
        ['x,1', 'he said "hi"'],
        ['l1\nl2', 'z'],
      ]);
    });
  });

  group('planCsvImport', () {
    test('brings back an export exactly, into an empty app', () {
      final csv = buildCsv(_source());
      final target = freshData();
      final plan = planCsvImport(csv, target, newId: _id);
      expect(plan.txns, hasLength(5));
      expect(plan.duplicates, 0);
      expect(plan.skipped, 0);
      expect(plan.newCategories.map((c) => c.name), ['Pets']);
      final pets = plan.newCategories.single;
      final bag = plan.txns.firstWhere((t) => t.amountCents == 450662);
      expect(bag.categoryId, pets.id);
      expect(bag.note, 'Food, "big" bag');
      expect(
        plan.txns.firstWhere((t) => t.kind == TxnKind.income).note,
        'Line 1\nLine 2',
      );
      expect(
        plan.txns.firstWhere((t) => t.amountCents == 99).categoryId,
        fallbackExpenseId,
      );
    });

    test('importing the same file again adds nothing', () {
      final csv = buildCsv(_source());
      final target = freshData();
      final first = planCsvImport(csv, target, newId: _id);
      target.categories.addAll(first.newCategories);
      target.txns.addAll(first.txns);
      final second = planCsvImport(csv, target, newId: _id);
      expect(second.txns, isEmpty);
      expect(second.newCategories, isEmpty);
      expect(second.duplicates, 5);
    });

    test('keeps two identical purchases made on the same day', () {
      final plan = planCsvImport(
        buildCsv(_source()),
        freshData(),
        newId: _id,
      );
      expect(plan.txns.where((t) => t.note == 'Lunch'), hasLength(2));
    });

    test('adds only what is missing when some rows are already there', () {
      final target = freshData();
      target.txns.add(
        _txn('x', TxnKind.expense, 12000, 'food', DateTime(2026, 11, 13), 'Lunch'),
      );
      final plan = planCsvImport(buildCsv(_source()), target, newId: _id);
      expect(plan.duplicates, 1);
      expect(plan.txns, hasLength(4));
      expect(plan.txns.where((t) => t.note == 'Lunch'), hasLength(1));
    });

    test('matches categories by name regardless of capitals', () {
      final plan = planCsvImport(
        'Date,Type,Category,Amount,Note\n2026-11-01,expense,GROCERIES,10.50,\n',
        freshData(),
        newId: _id,
      );
      expect(plan.newCategories, isEmpty);
      expect(plan.txns.single.categoryId, 'groceries');
      expect(plan.txns.single.amountCents, 1050);
    });

    test('skips rows it cannot read and says how many', () {
      final plan = planCsvImport(
        'Date,Type,Category,Amount,Note\n'
        'not-a-date,expense,Food & dining,5,\n'
        '2026-11-01,transfer,Food & dining,5,\n'
        '2026-11-01,expense,Food & dining,abc,\n'
        '2026-11-01,expense,Food & dining,0,\n'
        '\n'
        '2026-11-02,expense,Food & dining,7,ok\n',
        freshData(),
        newId: _id,
      );
      expect(plan.txns, hasLength(1));
      expect(plan.skipped, 4);
    });

    test('refuses files that are not a Tally CSV', () {
      expect(
        () => planCsvImport('', freshData(), newId: _id),
        throwsA(isA<CsvImportException>()),
      );
      expect(
        () => planCsvImport('name,total\nx,1\n', freshData(), newId: _id),
        throwsA(isA<CsvImportException>()),
      );
    });
  });
}
