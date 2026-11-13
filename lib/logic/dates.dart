/// Date helpers. All dates in Tally are calendar dates (no time of day).
library;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// Number of days in [month] (1-12) of [year]. Handles leap years.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Days left in the month of [today], counting today itself.
int daysLeftInMonth(DateTime today) =>
    daysInMonth(today.year, today.month) - today.day + 1;

/// The Sunday on or before [day]. Tally's weeks run Sunday to Saturday.
DateTime startOfWeek(DateTime day) => addDays(day, -(day.weekday % 7));

/// A single number identifying a calendar month, increasing by one per month.
int monthIndex(DateTime d) => d.year * 12 + d.month - 1;

DateTime monthFromIndex(int index) => DateTime(index ~/ 12, index % 12 + 1);

/// First day of the month [delta] months away from [month].
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

DateTime addDays(DateTime d, int delta) =>
    DateTime(d.year, d.month, d.day + delta);

/// Sortable integer such as 20261112.
int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

String dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime? parseDateKey(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final da = int.parse(m.group(3)!);
  final d = DateTime(y, mo, da);
  if (d.month != mo || d.day != da) return null;
  return d;
}
