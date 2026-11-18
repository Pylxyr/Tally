/// Reads the CSV that "Export as CSV" writes (Date, Type, Category, Amount,
/// Note) so transactions can be brought back into Tally. Pure Dart.
///
/// Import only adds. Rows that are already in the app are left out, and nothing
/// that is already stored is changed or removed.
library;

import 'dates.dart';
import 'defaults.dart';
import 'models.dart';
import 'money.dart';

/// Larger files are refused before anything is read.
const int maxCsvBytes = 20 * 1024 * 1024;

/// A file that cannot be imported. [message] is safe to show to the person.
class CsvImportException implements Exception {
  const CsvImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What an import would do, worked out before anything is changed.
class CsvImportPlan {
  const CsvImportPlan({
    required this.txns,
    required this.newCategories,
    required this.duplicates,
    required this.skipped,
  });

  /// Transactions to add.
  final List<Txn> txns;

  /// Categories to add because the file names ones the app does not have.
  final List<Category> newCategories;

  /// Rows left out because the same transaction is already in the app.
  final int duplicates;

  /// Rows left out because they could not be read.
  final int skipped;
}

/// Splits CSV text into rows of cells. Handles quoted cells with commas,
/// doubled quotes and line breaks, either line ending, and a leading BOM.
List<List<String>> parseCsv(String text) {
  final s = text.startsWith('﻿') ? text.substring(1) : text;
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < s.length) {
    final ch = s[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      cell.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\r' || ch == '\n') {
      if (ch == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

String _txnKey(String day, TxnKind kind, int cents, String category, String note) =>
    '$day|${kind.name}|$cents|$category|${note.trim()}';

/// Works out what importing [text] would add to [existing]. Throws
/// [CsvImportException] when the file is not a Tally CSV.
CsvImportPlan planCsvImport(
  String text,
  AppData existing, {
  required String Function() newId,
}) {
  final rows = parseCsv(text);
  final headerAt = rows.indexWhere((r) => r.any((c) => c.trim().isNotEmpty));
  if (headerAt < 0) throw const CsvImportException('That file is empty.');
  final header = [for (final c in rows[headerAt]) c.trim().toLowerCase()];
  final iDate = header.indexOf('date');
  final iType = header.indexOf('type');
  final iCategory = header.indexOf('category');
  final iAmount = header.indexOf('amount');
  final iNote = header.indexOf('note');
  if (iDate < 0 || iType < 0 || iAmount < 0) {
    throw const CsvImportException(
      'This does not look like a Tally CSV. It needs Date, Type and Amount '
      'columns.',
    );
  }

  // Categories are matched by name and kind, ignoring capital letters.
  final known = <String, Category>{
    for (final c in existing.categories)
      '${c.kind.name}|${c.name.trim().toLowerCase()}': c,
  };
  final created = <Category>[];

  String categoryIdFor(TxnKind kind, String rawName) {
    final name = rawName.trim();
    final fallback = kind == TxnKind.income
        ? fallbackIncomeId
        : fallbackExpenseId;
    if (name.isEmpty || name.toLowerCase() == 'unknown') return fallback;
    final key = '${kind.name}|${name.toLowerCase()}';
    final hit = known[key];
    if (hit != null) return hit.id;
    final category = Category(
      id: newId(),
      name: name,
      colorValue: categoryPalette[created.length % categoryPalette.length],
      kind: kind,
    );
    known[key] = category;
    created.add(category);
    return category.id;
  }

  // How many of each transaction the app already has. Each file row uses one
  // up, so importing the same file twice adds nothing, while two real
  // purchases with identical details on one day are both kept.
  final have = <String, int>{};
  for (final t in existing.txns) {
    final key = _txnKey(
      dateKey(t.date),
      t.kind,
      t.amountCents,
      t.categoryId,
      t.note,
    );
    have[key] = (have[key] ?? 0) + 1;
  }

  String cell(List<String> row, int i) =>
      i >= 0 && i < row.length ? row[i] : '';

  final txns = <Txn>[];
  var duplicates = 0;
  var skipped = 0;
  for (var r = headerAt + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.trim().isEmpty)) continue;
    final date = parseDateKey(cell(row, iDate).trim());
    final type = cell(row, iType).trim().toLowerCase();
    final cents = parseCents(cell(row, iAmount));
    if (date == null ||
        cents == null ||
        cents <= 0 ||
        (type != 'income' && type != 'expense')) {
      skipped++;
      continue;
    }
    final kind = type == 'income' ? TxnKind.income : TxnKind.expense;
    final categoryId = categoryIdFor(kind, cell(row, iCategory));
    final note = cell(row, iNote).trim();
    final key = _txnKey(dateKey(date), kind, cents, categoryId, note);
    final left = have[key] ?? 0;
    if (left > 0) {
      have[key] = left - 1;
      duplicates++;
      continue;
    }
    txns.add(
      Txn(
        id: newId(),
        kind: kind,
        amountCents: cents,
        categoryId: categoryId,
        date: date,
        note: note,
      ),
    );
  }
  return CsvImportPlan(
    txns: txns,
    newCategories: created,
    duplicates: duplicates,
    skipped: skipped,
  );
}
