/// Money and text formatting. Amounts are whole minor units (cents).
library;

import 'dates.dart';

const List<String> monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Index 0 is Monday, matching [DateTime.weekday] - 1.
const List<String> weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String _group(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Formats [cents] like `₱1,250` or `₱1,250.50`. Decimals only appear when
/// needed. A typographic minus is used for negatives.
String formatMoney(int cents, String symbol, {bool showPlus = false}) {
  final neg = cents < 0;
  final abs = cents.abs();
  final whole = abs ~/ 100;
  final frac = abs % 100;
  final body = frac == 0
      ? _group(whole)
      : '${_group(whole)}.${frac.toString().padLeft(2, '0')}';
  final sign = neg ? '\u2212' : (showPlus && cents > 0 ? '+' : '');
  return '$sign$symbol$body';
}

/// Whole-unit amount, rounded down. Used for the "safe to spend" number so the
/// figure is never optimistic.
int floorToUnits(double cents) => (cents / 100).floor();

/// Parses user input such as `1250`, `1250.5` or `.5` into cents.
/// Returns null when the text is empty or not a valid amount.
int? parseCents(String input) {
  final s = input.trim().replaceAll(',', '.');
  if (s.isEmpty || s == '.') return null;
  if (!RegExp(r'^\d{0,10}(\.\d{0,2})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  final whole = parts[0].isEmpty ? 0 : int.parse(parts[0]);
  final frac = (parts.length > 1 ? parts[1] : '').padRight(2, '0');
  return whole * 100 + int.parse(frac);
}

/// Inverse of [parseCents], used to pre-fill text fields.
String centsToInput(int cents) {
  final whole = cents ~/ 100;
  final frac = cents % 100;
  return frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
}

/// Always two decimals, no symbol or grouping. Used in CSV export.
String centsToPlain(int cents) {
  final whole = cents ~/ 100;
  final frac = cents % 100;
  return '$whole.${frac.toString().padLeft(2, '0')}';
}

String formatMonth(DateTime d) => '${monthNames[d.month - 1]} ${d.year}';

String formatShortDate(DateTime d) =>
    '${weekdayShort[d.weekday - 1]}, ${d.day} ${monthShort[d.month - 1]}';

/// "Today", "Yesterday" or "Wed, 12 Nov" (with the year when not this year).
String formatDayLabel(DateTime day, DateTime today) {
  if (isSameDay(day, today)) return 'Today';
  if (isSameDay(day, addDays(today, -1))) return 'Yesterday';
  final base = formatShortDate(day);
  return day.year == today.year ? base : '$base ${day.year}';
}

/// "5th", "22nd" and so on.
String ordinal(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}
