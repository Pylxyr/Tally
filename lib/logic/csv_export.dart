import 'dates.dart';
import 'models.dart';
import 'money.dart';

String _cell(String s) {
  if (s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Builds a CSV of every transaction, oldest first. Starts with a UTF-8 byte
/// order mark so spreadsheets read non-ASCII notes correctly.
String buildCsv(AppData data) {
  final names = {for (final c in data.categories) c.id: c.name};
  final rows = [...data.txns]
    ..sort((a, b) {
      final c = dayKey(a.date).compareTo(dayKey(b.date));
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final buf = StringBuffer('\uFEFF');
  buf.write('Date,Type,Category,Amount,Note\r\n');
  for (final t in rows) {
    buf
      ..write(dateKey(t.date))
      ..write(',')
      ..write(t.kind == TxnKind.income ? 'income' : 'expense')
      ..write(',')
      ..write(_cell(names[t.categoryId] ?? 'Unknown'))
      ..write(',')
      ..write(centsToPlain(t.amountCents))
      ..write(',')
      ..write(_cell(t.note))
      ..write('\r\n');
  }
  return buf.toString();
}
